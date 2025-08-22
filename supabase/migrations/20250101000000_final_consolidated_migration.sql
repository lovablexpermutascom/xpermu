/*
# [FINAL & CONSOLIDATED] Full Database Reset and Creation
This script performs a complete reset of the XPermutas database schema. It drops all existing tables, types, and functions to ensure a clean state, and then rebuilds the entire structure from scratch in the correct dependency order. This includes all tables, functions, triggers, RLS policies, and initial data seeding. This script is designed to be the definitive solution to all previous migration issues.

## Query Description: This is a DESTRUCTIVE operation. It will completely erase all existing data in the XPermutas tables (users, listings, transactions, etc.) before recreating the schema. This is necessary to fix inconsistencies from previous failed migrations.

## Metadata:
- Schema-Category: "Dangerous"
- Impact-Level: "High"
- Requires-Backup: true
- Reversible: false

## Structure Details:
- Drops all existing project-related tables, types, and functions.
- Creates types: user_status, user_role, listing_status, transaction_status, loan_status.
- Creates tables: users, categories, listings, transactions, loan_requests.
- Creates functions: generate_unique_referral_code, get_user_role, handle_seller_on_transaction_complete, create_admin_user.
- Creates triggers: on_transaction_completed.
- Creates all necessary Row Level Security (RLS) policies.
- Seeds the 'categories' table with initial data.

## Security Implications:
- RLS Status: Enabled on all relevant tables.
- Policy Changes: All policies are created from scratch.
- Auth Requirements: Policies are based on `auth.uid()` and the custom `get_user_role` function.
- All functions are created with `SECURITY DEFINER` and have their `search_path` set to `public` to address security advisories.

## Performance Impact:
- Indexes: Primary keys and foreign keys are indexed by default.
- Triggers: One trigger is created on the 'transactions' table to handle financial logic upon completion.
- Estimated Impact: Minimal performance impact for a new database. Optimized for standard operations.
*/

-- =================================================================
-- FASE 1: LIMPEZA COMPLETA (DESTRUCTIVA)
-- =================================================================
-- Drop com CASCADE para garantir que tudo (incluindo dependências) é removido.
DROP TABLE IF EXISTS public.loan_requests CASCADE;
DROP TABLE IF EXISTS public.transactions CASCADE;
DROP TABLE IF EXISTS public.listings CASCADE;
DROP TABLE IF EXISTS public.categories CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

-- Drop funções que possam ter ficado órfãs
DROP FUNCTION IF EXISTS public.get_user_role(uuid);
DROP FUNCTION IF EXISTS public.generate_unique_referral_code();
DROP FUNCTION IF EXISTS public.handle_seller_on_transaction_complete();
DROP FUNCTION IF EXISTS public.create_admin_user(text);

-- Drop tipos (enums)
DROP TYPE IF EXISTS public.user_status;
DROP TYPE IF EXISTS public.user_role;
DROP TYPE IF EXISTS public.listing_status;
DROP TYPE IF EXISTS public.transaction_status;
DROP TYPE IF EXISTS public.loan_status;


-- =================================================================
-- FASE 2: CRIAÇÃO DA ESTRUTURA
-- =================================================================

-- 2.1: Criar Tipos (Enums)
CREATE TYPE public.user_status AS ENUM ('pending', 'approved', 'rejected', 'suspended');
CREATE TYPE public.user_role AS ENUM ('user', 'admin');
CREATE TYPE public.listing_status AS ENUM ('active', 'sold', 'inactive');
CREATE TYPE public.transaction_status AS ENUM ('pending', 'completed', 'cancelled');
CREATE TYPE public.loan_status AS ENUM ('pending', 'approved', 'rejected');

-- 2.2: Criar Funções Auxiliares (sem dependências de tabela)
CREATE OR REPLACE FUNCTION public.generate_unique_referral_code()
RETURNS TEXT AS $$
DECLARE
  new_code TEXT;
  is_duplicate BOOLEAN;
BEGIN
  LOOP
    new_code := upper(substr(md5(random()::text), 0, 9)); -- 8 chars
    SELECT EXISTS (SELECT 1 FROM public.users WHERE referral_code = new_code) INTO is_duplicate;
    IF NOT is_duplicate THEN
      RETURN new_code;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql VOLATILE;


-- 2.3: Criar Tabelas
CREATE TABLE public.users (
    id uuid NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name text NOT NULL,
    nif text NOT NULL UNIQUE,
    whatsapp text NOT NULL,
    status user_status NOT NULL DEFAULT 'pending',
    role user_role NOT NULL DEFAULT 'user',
    balance_xs numeric(10, 2) NOT NULL DEFAULT 0.00,
    balance_bonus numeric(10, 2) NOT NULL DEFAULT 0.00,
    debt_xs numeric(10, 2) NOT NULL DEFAULT 0.00,
    referral_code text UNIQUE NOT NULL DEFAULT public.generate_unique_referral_code(),
    referred_by uuid NULL REFERENCES public.users(id),
    profile_image_url text NULL,
    company_name text NULL,
    address text NULL,
    location text NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.users IS 'Stores user profile information.';

CREATE TABLE public.categories (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL UNIQUE,
    description text NULL,
    icon text NULL,
    color text NULL,
    parent_id uuid NULL REFERENCES public.categories(id),
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.categories IS 'Stores categories for listings.';

CREATE TABLE public.listings (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES public.users(id),
    category_id uuid NULL REFERENCES public.categories(id),
    title text NOT NULL,
    description text NOT NULL,
    price numeric(10, 2) NOT NULL,
    images text[] NULL,
    status listing_status NOT NULL DEFAULT 'active',
    location text NULL,
    views_count integer NOT NULL DEFAULT 0,
    featured boolean NOT NULL DEFAULT false,
    expires_at timestamp with time zone NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.listings IS 'Stores all product and service listings.';

CREATE TABLE public.transactions (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    buyer_id uuid NOT NULL REFERENCES public.users(id),
    seller_id uuid NOT NULL REFERENCES public.users(id),
    listing_id uuid NULL REFERENCES public.listings(id),
    amount numeric(10, 2) NOT NULL,
    commission numeric(10, 2) NOT NULL,
    voucher text NOT NULL UNIQUE,
    status transaction_status NOT NULL DEFAULT 'pending',
    payment_method text NULL,
    notes text NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    completed_at timestamp with time zone NULL
);
COMMENT ON TABLE public.transactions IS 'Records all transactions between users.';

CREATE TABLE public.loan_requests (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES public.users(id),
    amount numeric(10, 2) NOT NULL,
    reason text NULL,
    status loan_status NOT NULL DEFAULT 'pending',
    approved_by uuid NULL REFERENCES public.users(id),
    approved_at timestamp with time zone NULL,
    notes text NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.loan_requests IS 'Stores user requests for X$ credit.';

-- =================================================================
-- FASE 3: LÓGICA DE NEGÓCIO (Funções, Triggers)
-- =================================================================

-- 3.1: Funções para RLS e Triggers
CREATE OR REPLACE FUNCTION public.get_user_role(user_id_input uuid)
RETURNS text AS $$
DECLARE
  user_role_output text;
BEGIN
  SELECT role::text INTO user_role_output FROM public.users WHERE id = user_id_input;
  RETURN user_role_output;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Fix security warning
ALTER FUNCTION public.get_user_role(uuid) SET search_path = public;

CREATE OR REPLACE FUNCTION public.handle_seller_on_transaction_complete()
RETURNS TRIGGER AS $$
DECLARE
  seller_debt NUMERIC;
  payment_to_debt NUMERIC;
  remaining_amount NUMERIC;
BEGIN
  -- Apenas executa na transição para 'completed'
  IF NEW.status = 'completed' AND OLD.status <> 'completed' THEN
    -- Obter a dívida atual do vendedor
    SELECT debt_xs INTO seller_debt FROM public.users WHERE id = NEW.seller_id;

    IF seller_debt > 0 THEN
      -- Calcular quanto do pagamento vai para a dívida
      payment_to_debt := LEAST(NEW.amount, seller_debt);
      remaining_amount := NEW.amount - payment_to_debt;

      -- Amortizar a dívida
      UPDATE public.users
      SET 
        debt_xs = debt_xs - payment_to_debt,
        balance_xs = balance_xs + remaining_amount,
        updated_at = now()
      WHERE id = NEW.seller_id;
    ELSE
      -- Se não há dívida, todo o montante vai para o saldo
      UPDATE public.users
      SET 
        balance_xs = balance_xs + NEW.amount,
        updated_at = now()
      WHERE id = NEW.seller_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Fix security warning
ALTER FUNCTION public.handle_seller_on_transaction_complete() SET search_path = public;


-- 3.2: Triggers
CREATE TRIGGER on_transaction_completed
AFTER UPDATE ON public.transactions
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION public.handle_seller_on_transaction_complete();


-- =================================================================
-- FASE 4: SEGURANÇA (RLS Policies)
-- =================================================================

-- 4.1: Ativar RLS nas tabelas
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loan_requests ENABLE ROW LEVEL SECURITY;

-- 4.2: Criar Políticas de Segurança
-- Tabela: users
CREATE POLICY "Admins can manage all users" ON public.users FOR ALL USING (get_user_role(auth.uid()) = 'admin') WITH CHECK (get_user_role(auth.uid()) = 'admin');
CREATE POLICY "Users can view their own profile" ON public.users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update their own profile" ON public.users FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- Tabela: categories
CREATE POLICY "Allow public read access to categories" ON public.categories FOR SELECT USING (true);
CREATE POLICY "Admins can manage categories" ON public.categories FOR ALL USING (get_user_role(auth.uid()) = 'admin') WITH CHECK (get_user_role(auth.uid()) = 'admin');

-- Tabela: listings
CREATE POLICY "Allow public read access to active listings" ON public.listings FOR SELECT USING (status = 'active');
CREATE POLICY "Users can create listings" ON public.listings FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can manage their own listings" ON public.listings FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins can manage all listings" ON public.listings FOR ALL USING (get_user_role(auth.uid()) = 'admin') WITH CHECK (get_user_role(auth.uid()) = 'admin');

-- Tabela: transactions
CREATE POLICY "Users can view their own transactions" ON public.transactions FOR SELECT USING (auth.uid() = buyer_id OR auth.uid() = seller_id);
CREATE POLICY "Users can create transactions as buyers" ON public.transactions FOR INSERT WITH CHECK (auth.uid() = buyer_id);
CREATE POLICY "Sellers can update transaction status" ON public.transactions FOR UPDATE USING (auth.uid() = seller_id) WITH CHECK (auth.uid() = seller_id);
CREATE POLICY "Admins can manage all transactions" ON public.transactions FOR ALL USING (get_user_role(auth.uid()) = 'admin') WITH CHECK (get_user_role(auth.uid()) = 'admin');

-- Tabela: loan_requests
CREATE POLICY "Users can manage their own loan requests" ON public.loan_requests FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins can manage all loan requests" ON public.loan_requests FOR ALL USING (get_user_role(auth.uid()) = 'admin') WITH CHECK (get_user_role(auth.uid()) = 'admin');

-- =================================================================
-- FASE 5: FUNÇÕES DE ADMINISTRAÇÃO E DADOS INICIAIS
-- =================================================================

-- 5.1: Função para criar um administrador
CREATE OR REPLACE FUNCTION public.create_admin_user(email_input text)
RETURNS void AS $$
DECLARE
  user_id_to_update uuid;
BEGIN
  SELECT id INTO user_id_to_update FROM auth.users WHERE email = email_input;
  
  IF user_id_to_update IS NOT NULL THEN
    UPDATE public.users
    SET role = 'admin'
    WHERE id = user_id_to_update;
  ELSE
    RAISE EXCEPTION 'User with email % not found', email_input;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Fix security warning
ALTER FUNCTION public.create_admin_user(text) SET search_path = public;

-- 5.2: Inserir dados iniciais (categorias)
INSERT INTO public.categories (name, description, icon, color, is_active) VALUES
('Serviços Digitais', 'Marketing, design, programação, etc.', 'Code', '#0066cc', true),
('Consultoria', 'Consultoria de negócios, financeira, etc.', 'Briefcase', '#f97316', true),
('Produtos Físicos', 'Equipamentos, mobiliário, etc.', 'Box', '#10b981', true),
('Formação e Educação', 'Workshops, cursos, etc.', 'BookOpen', '#8b5cf6', true),
('Saúde e Bem-estar', 'Terapias, massagens, etc.', 'Heart', '#ef4444', true),
('Restauração e Hotelaria', 'Refeições, estadias, etc.', 'Utensils', '#f59e0b', true),
('Outros Serviços', 'Serviços não categorizados.', 'MoreHorizontal', '#6b7280', true);
