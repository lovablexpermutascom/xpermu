/*
  # [FINAL MIGRATION] Full Database Reset and Setup
  This is a consolidated script to completely reset and rebuild the database schema.
  It includes all tables, functions, RLS policies, and security fixes.
  This script is designed to be run on a clean or inconsistent database to bring it to the correct state.

  ## Query Description:
  - This operation is DESTRUCTIVE. It will drop all existing tables and data.
  - It rebuilds the entire schema from scratch.
  - It includes security best practices (e.g., setting search_path).

  ## Metadata:
  - Schema-Category: "Dangerous"
  - Impact-Level: "High"
  - Requires-Backup: true
  - Reversible: false
*/

-- Step 1: Drop existing objects in reverse order of dependency
DROP TRIGGER IF EXISTS on_transaction_completed ON public.transactions CASCADE;
DROP FUNCTION IF EXISTS public.handle_seller_on_transaction_complete() CASCADE;
DROP FUNCTION IF EXISTS public.create_admin_user(text) CASCADE;
DROP FUNCTION IF EXISTS public.generate_unique_referral_code() CASCADE;

DROP TABLE IF EXISTS public.loan_requests CASCADE;
DROP TABLE IF EXISTS public.transactions CASCADE;
DROP TABLE IF EXISTS public.listings CASCADE;
DROP TABLE IF EXISTS public.categories CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

DROP TYPE IF EXISTS public.user_status CASCADE;
DROP TYPE IF EXISTS public.user_role CASCADE;
DROP TYPE IF EXISTS public.listing_status CASCADE;
DROP TYPE IF EXISTS public.transaction_status CASCADE;
DROP TYPE IF EXISTS public.loan_request_status CASCADE;

-- Step 2: Create custom types (Enums)
CREATE TYPE public.user_status AS ENUM ('pending', 'approved', 'rejected', 'suspended');
CREATE TYPE public.user_role AS ENUM ('user', 'admin');
CREATE TYPE public.listing_status AS ENUM ('active', 'sold', 'inactive');
CREATE TYPE public.transaction_status AS ENUM ('pending', 'completed', 'cancelled');
CREATE TYPE public.loan_request_status AS ENUM ('pending', 'approved', 'rejected');

-- Step 3: Create Tables
-- Users Table
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
    referral_code text UNIQUE,
    referred_by uuid REFERENCES public.users(id),
    profile_image_url text,
    company_name text,
    address text,
    location text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Categories Table
CREATE TABLE public.categories (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL UNIQUE,
    description text,
    icon text,
    color text,
    parent_id uuid REFERENCES public.categories(id),
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Listings Table
CREATE TABLE public.listings (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.users(id),
    category_id uuid REFERENCES public.categories(id),
    title text NOT NULL,
    description text NOT NULL,
    price numeric(10, 2) NOT NULL,
    images text[],
    status listing_status NOT NULL DEFAULT 'active',
    location text,
    views_count integer NOT NULL DEFAULT 0,
    featured boolean NOT NULL DEFAULT false,
    expires_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Transactions Table
CREATE TABLE public.transactions (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    buyer_id uuid NOT NULL REFERENCES public.users(id),
    seller_id uuid NOT NULL REFERENCES public.users(id),
    listing_id uuid REFERENCES public.listings(id),
    amount numeric(10, 2) NOT NULL,
    commission numeric(10, 2) NOT NULL,
    voucher text NOT NULL UNIQUE,
    status transaction_status NOT NULL DEFAULT 'pending',
    payment_method text,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    completed_at timestamptz,
    CONSTRAINT buyer_seller_different CHECK (buyer_id <> seller_id)
);

-- Loan Requests Table
CREATE TABLE public.loan_requests (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.users(id),
    amount numeric(10, 2) NOT NULL,
    reason text,
    status loan_request_status NOT NULL DEFAULT 'pending',
    approved_by uuid REFERENCES public.users(id),
    approved_at timestamptz,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Step 4: Create Functions
-- Function to generate a unique referral code
CREATE OR REPLACE FUNCTION public.generate_unique_referral_code()
RETURNS text
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  new_code text;
  is_duplicate boolean;
BEGIN
  LOOP
    new_code := upper(substr(md5(random()::text), 0, 7));
    SELECT EXISTS (SELECT 1 FROM public.users WHERE referral_code = new_code) INTO is_duplicate;
    IF NOT is_duplicate THEN
      RETURN new_code;
    END IF;
  END LOOP;
END;
$$;

-- Function to create an admin user
CREATE OR REPLACE FUNCTION public.create_admin_user(admin_email text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_id_to_update uuid;
BEGIN
  SELECT id INTO user_id_to_update FROM auth.users WHERE email = admin_email;
  IF user_id_to_update IS NOT NULL THEN
    UPDATE public.users
    SET role = 'admin', status = 'approved'
    WHERE id = user_id_to_update;
  ELSE
    RAISE EXCEPTION 'User with email % not found', admin_email;
  END IF;
END;
$$;

-- Function to handle transaction completion
CREATE OR REPLACE FUNCTION public.handle_seller_on_transaction_complete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  seller_debt numeric;
  amortization_amount numeric;
  remaining_amount numeric;
BEGIN
  -- Only run on UPDATE when status changes to 'completed'
  IF TG_OP = 'UPDATE' AND NEW.status = 'completed' AND OLD.status <> 'completed' THEN
    SELECT debt_xs INTO seller_debt FROM public.users WHERE id = NEW.seller_id;

    IF seller_debt > 0 THEN
      -- 100% of sale goes to pay off debt
      amortization_amount := LEAST(NEW.amount, seller_debt);
      
      UPDATE public.users
      SET debt_xs = debt_xs - amortization_amount
      WHERE id = NEW.seller_id;
      
      remaining_amount := NEW.amount - amortization_amount;
    ELSE
      remaining_amount := NEW.amount;
    END IF;

    -- Add any remaining amount to the seller's balance
    IF remaining_amount > 0 THEN
      UPDATE public.users
      SET balance_xs = balance_xs + remaining_amount
      WHERE id = NEW.seller_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Step 5: Create Triggers
-- Trigger to set a referral code for new users
CREATE TRIGGER set_referral_code
BEFORE INSERT ON public.users
FOR EACH ROW
EXECUTE FUNCTION a_new_function();

-- Trigger for transaction completion
CREATE TRIGGER on_transaction_completed
AFTER UPDATE ON public.transactions
FOR EACH ROW
EXECUTE FUNCTION public.handle_seller_on_transaction_complete();

-- Step 6: Enable Row Level Security (RLS)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loan_requests ENABLE ROW LEVEL SECURITY;

-- Step 7: Create RLS Policies
-- Users
CREATE POLICY "Users can view their own data" ON public.users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update their own data" ON public.users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admins can manage all users" ON public.users FOR ALL USING (
  (SELECT role FROM public.users WHERE id = auth.uid()) = 'admin'
);

-- Categories
CREATE POLICY "All users can view categories" ON public.categories FOR SELECT USING (true);
CREATE POLICY "Admins can manage categories" ON public.categories FOR ALL USING (
  (SELECT role FROM public.users WHERE id = auth.uid()) = 'admin'
);

-- Listings
CREATE POLICY "All users can view active listings" ON public.listings FOR SELECT USING (status = 'active');
CREATE POLICY "Users can manage their own listings" ON public.listings FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Admins can manage all listings" ON public.listings FOR ALL USING (
  (SELECT role FROM public.users WHERE id = auth.uid()) = 'admin'
);

-- Transactions
CREATE POLICY "Users can view their own transactions" ON public.transactions FOR SELECT USING (auth.uid() = buyer_id OR auth.uid() = seller_id);
CREATE POLICY "Admins can manage all transactions" ON public.transactions FOR ALL USING (
  (SELECT role FROM public.users WHERE id = auth.uid()) = 'admin'
);

-- Loan Requests
CREATE POLICY "Users can manage their own loan requests" ON public.loan_requests FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Admins can manage all loan requests" ON public.loan_requests FOR ALL USING (
  (SELECT role FROM public.users WHERE id = auth.uid()) = 'admin'
);

-- Step 8: Seed initial data
-- Seed Categories
INSERT INTO public.categories (name, description, icon, color) VALUES
('Serviços Profissionais', 'Consultoria, design, programação, etc.', 'briefcase', '#3b82f6'),
('Eletrónica', 'Computadores, telemóveis, gadgets.', 'smartphone', '#ef4444'),
('Casa e Jardim', 'Mobiliário, decoração, ferramentas.', 'home', '#22c55e'),
('Moda e Acessórios', 'Roupa, calçado, jóias.', 'shirt', '#a855f7'),
('Automóveis e Peças', 'Veículos, peças, serviços de mecânica.', 'car', '#f97316'),
('Lazer e Desporto', 'Equipamento desportivo, bilhetes, experiências.', 'dices', '#14b8a6'),
('Imobiliário', 'Arrendamento, permuta de imóveis.', 'building-2', '#6366f1'),
('Outros', 'Itens e serviços diversos.', 'package', '#71717a');
