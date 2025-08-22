/*
  # =================================================================
  # XPERMUTAS - SCRIPT DE MIGRAÇÃO CONSOLIDADO E CORRIGIDO
  # =================================================================
  # Este script apaga a estrutura existente e reconstrói a base de 
  # dados para garantir um estado consistente, limpo e seguro.
  # Execute este script para resolver todos os erros de migração anteriores.
  # =================================================================
*/

-- =============================================
-- 1. LIMPEZA (DROPPING EXISTING OBJECTS)
-- =============================================
-- Drop triggers first to remove dependencies
DROP TRIGGER IF EXISTS on_transaction_complete ON public.transactions;

-- Drop functions
DROP FUNCTION IF EXISTS public.handle_seller_on_transaction_complete();
DROP FUNCTION IF EXISTS public.create_admin_user(admin_email TEXT);
DROP FUNCTION IF EXISTS public.generate_referral_code();
DROP FUNCTION IF EXISTS public.is_admin(user_id UUID);

-- Drop tables (use CASCADE to remove dependent objects like policies)
DROP TABLE IF EXISTS public.loan_requests CASCADE;
DROP TABLE IF EXISTS public.transactions CASCADE;
DROP TABLE IF EXISTS public.listings CASCADE;
DROP TABLE IF EXISTS public.categories CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

-- Drop custom types
DROP TYPE IF EXISTS public.user_status;
DROP TYPE IF EXISTS public.user_role;
DROP TYPE IF EXISTS public.listing_status;
DROP TYPE IF EXISTS public.transaction_status;
DROP TYPE IF EXISTS public.loan_request_status;

-- =============================================
-- 2. CREATE CUSTOM TYPES
-- =============================================
CREATE TYPE public.user_status AS ENUM ('pending', 'approved', 'rejected', 'suspended');
CREATE TYPE public.user_role AS ENUM ('user', 'admin');
CREATE TYPE public.listing_status AS ENUM ('active', 'sold', 'inactive');
CREATE TYPE public.transaction_status AS ENUM ('pending', 'completed', 'cancelled');
CREATE TYPE public.loan_request_status AS ENUM ('pending', 'approved', 'rejected');

-- =============================================
-- 3. CREATE FUNCTIONS
-- =============================================
/*
  # [Function] generate_referral_code
  Generates a unique 8-character alphanumeric referral code.
*/
CREATE OR REPLACE FUNCTION public.generate_referral_code()
RETURNS TEXT AS $$
DECLARE
  new_code TEXT;
  found BOOLEAN;
BEGIN
  LOOP
    new_code := (
      SELECT string_agg(c, '')
      FROM (
        SELECT c
        FROM unnest(string_to_array('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', NULL)) AS c
        ORDER BY random()
        LIMIT 8
      ) AS s
    );
    SELECT EXISTS (SELECT 1 FROM public.users WHERE referral_code = new_code) INTO found;
    IF NOT found THEN
      RETURN new_code;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;
ALTER FUNCTION public.generate_referral_code() SET search_path = public;

/*
  # [Function] handle_seller_on_transaction_complete
  Trigger function to handle logic when a transaction is completed.
*/
CREATE OR REPLACE FUNCTION public.handle_seller_on_transaction_complete()
RETURNS TRIGGER AS $$
DECLARE
  seller_debt NUMERIC;
  payment_to_debt NUMERIC;
  remaining_amount NUMERIC;
BEGIN
  IF (TG_OP = 'UPDATE' AND NEW.status = 'completed' AND OLD.status != 'completed') THEN
    SELECT debt_xs INTO seller_debt FROM public.users WHERE id = NEW.seller_id;
    IF seller_debt > 0 THEN
      payment_to_debt := LEAST(NEW.amount, seller_debt);
      UPDATE public.users SET debt_xs = debt_xs - payment_to_debt WHERE id = NEW.seller_id;
      remaining_amount := NEW.amount - payment_to_debt;
    ELSE
      remaining_amount := NEW.amount;
    END IF;
    IF remaining_amount > 0 THEN
      UPDATE public.users SET balance_xs = balance_xs + remaining_amount WHERE id = NEW.seller_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
ALTER FUNCTION public.handle_seller_on_transaction_complete() SET search_path = public;

-- =============================================
-- 4. CREATE TABLES & TRIGGERS
-- =============================================
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  nif TEXT UNIQUE NOT NULL,
  whatsapp TEXT NOT NULL,
  status user_status NOT NULL DEFAULT 'pending',
  role user_role NOT NULL DEFAULT 'user',
  balance_xs NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
  balance_bonus NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
  debt_xs NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
  referral_code TEXT UNIQUE NOT NULL DEFAULT public.generate_referral_code(),
  referred_by UUID REFERENCES public.users(id),
  profile_image_url TEXT,
  company_name TEXT,
  address TEXT,
  location TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  icon TEXT,
  color TEXT,
  parent_id UUID REFERENCES public.categories(id),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.listings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id),
  category_id UUID REFERENCES public.categories(id),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  price NUMERIC(10, 2) NOT NULL,
  images TEXT[],
  status listing_status NOT NULL DEFAULT 'active',
  location TEXT,
  views_count INT NOT NULL DEFAULT 0,
  featured BOOLEAN NOT NULL DEFAULT false,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  buyer_id UUID NOT NULL REFERENCES public.users(id),
  seller_id UUID NOT NULL REFERENCES public.users(id),
  listing_id UUID REFERENCES public.listings(id),
  amount NUMERIC(10, 2) NOT NULL,
  commission NUMERIC(10, 2) NOT NULL,
  voucher TEXT UNIQUE NOT NULL,
  status transaction_status NOT NULL DEFAULT 'pending',
  payment_method TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ
);

CREATE TRIGGER on_transaction_complete
AFTER UPDATE ON public.transactions
FOR EACH ROW
EXECUTE FUNCTION public.handle_seller_on_transaction_complete();

CREATE TABLE public.loan_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id),
  amount NUMERIC(10, 2) NOT NULL,
  reason TEXT,
  status loan_request_status NOT NULL DEFAULT 'pending',
  approved_by UUID REFERENCES public.users(id),
  approved_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =============================================
-- 5. HELPER FUNCTIONS FOR RLS
-- =============================================
CREATE OR REPLACE FUNCTION public.is_admin(user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  user_role public.user_role;
BEGIN
  SELECT role INTO user_role FROM public.users WHERE id = user_id;
  RETURN user_role = 'admin';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
ALTER FUNCTION public.is_admin(user_id UUID) SET search_path = public;

CREATE OR REPLACE FUNCTION public.create_admin_user(admin_email TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE public.users
  SET role = 'admin'
  WHERE id = (SELECT id FROM auth.users WHERE email = admin_email);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
ALTER FUNCTION public.create_admin_user(admin_email TEXT) SET search_path = public;

-- =============================================
-- 6. ENABLE RLS & CREATE POLICIES
-- =============================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loan_requests ENABLE ROW LEVEL SECURITY;

-- Policies for 'users'
CREATE POLICY "Allow authenticated users to read all user profiles" ON public.users FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow user to update their own profile" ON public.users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Allow admin to manage all user profiles" ON public.users FOR ALL USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

-- Policies for 'categories'
CREATE POLICY "Allow authenticated users to read categories" ON public.categories FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin to manage categories" ON public.categories FOR ALL USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

-- Policies for 'listings'
CREATE POLICY "Allow authenticated users to read active listings" ON public.listings FOR SELECT USING (status = 'active');
CREATE POLICY "Allow user to manage their own listings" ON public.listings FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Allow admin to manage all listings" ON public.listings FOR ALL USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

-- Policies for 'transactions'
CREATE POLICY "Allow user to view their own transactions" ON public.transactions FOR SELECT USING (auth.uid() = buyer_id OR auth.uid() = seller_id);
CREATE POLICY "Allow admin to view all transactions" ON public.transactions FOR SELECT USING (public.is_admin(auth.uid()));

-- Policies for 'loan_requests'
CREATE POLICY "Allow user to manage their own loan requests" ON public.loan_requests FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Allow admin to manage all loan requests" ON public.loan_requests FOR ALL USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));
