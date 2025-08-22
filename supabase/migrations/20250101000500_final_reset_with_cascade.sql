/*
* XPermutas.com - Final Reset Script
*
* ## Query Description:
* This script performs a complete reset of the database. It DROPS all existing tables, functions, and types
* related to the application to ensure a clean slate, then rebuilds the entire schema from scratch.
* This is a DESTRUCTIVE operation on the public schema. All data in these tables will be lost.
*
* ## Metadata:
* - Schema-Category: "Dangerous"
* - Impact-Level: "High"
* - Requires-Backup: true
* - Reversible: false
*
* ## Security Implications:
* - RLS Status: Re-enabled on all tables.
* - Policy Changes: All policies are redefined from scratch.
*/

-- Step 1: Drop everything with CASCADE to handle all dependencies.
DROP FUNCTION IF EXISTS public.create_admin_user(text) CASCADE;
DROP FUNCTION IF EXISTS public.amortize_loan_on_sale() CASCADE;
DROP FUNCTION IF EXISTS public.generate_referral_code() CASCADE;

DROP TABLE IF EXISTS public.loan_requests CASCADE;
DROP TABLE IF EXISTS public.transactions CASCADE;
DROP TABLE IF EXISTS public.listings CASCADE;
DROP TABLE IF EXISTS public.categories CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

DROP TYPE IF EXISTS public.user_status CASCADE;
DROP TYPE IF EXISTS public.user_role CASCADE;
DROP TYPE IF EXISTS public.listing_status CASCADE;
DROP TYPE IF EXISTS public.transaction_status CASCADE;
DROP TYPE IF EXISTS public.loan_status CASCADE;

-- Step 2: Recreate the entire schema.

-- Create custom types (Enums)
CREATE TYPE public.user_status AS ENUM ('pending', 'approved', 'rejected', 'suspended');
CREATE TYPE public.user_role AS ENUM ('user', 'admin');
CREATE TYPE public.listing_status AS ENUM ('active', 'sold', 'inactive');
CREATE TYPE public.transaction_status AS ENUM ('pending', 'completed', 'cancelled');
CREATE TYPE public.loan_status AS ENUM ('pending', 'approved', 'rejected');

-- Create users table
CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    nif TEXT NOT NULL UNIQUE,
    whatsapp TEXT NOT NULL UNIQUE,
    status user_status NOT NULL DEFAULT 'pending',
    role user_role NOT NULL DEFAULT 'user',
    balance_xs NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    balance_bonus NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    debt_xs NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    referral_code TEXT UNIQUE,
    referred_by UUID REFERENCES public.users(id),
    profile_image_url TEXT,
    company_name TEXT,
    address TEXT,
    location TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.users IS 'Stores user profile information.';

-- Function to generate a unique referral code
CREATE OR REPLACE FUNCTION public.generate_referral_code()
RETURNS TRIGGER AS $$
BEGIN
    NEW.referral_code := 'XP-' || substr(md5(random()::text), 0, 7);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
ALTER FUNCTION public.generate_referral_code() SET search_path = public;

-- Trigger to auto-generate referral code for new users
CREATE TRIGGER on_new_user_created
BEFORE INSERT ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.generate_referral_code();

-- Create categories table
CREATE TABLE public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    icon TEXT,
    color TEXT,
    parent_id UUID REFERENCES public.categories(id),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.categories IS 'Stores listing categories.';

-- Create listings table
CREATE TABLE public.listings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    category_id UUID REFERENCES public.categories(id),
    title TEXT NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL,
    images TEXT[],
    status listing_status NOT NULL DEFAULT 'active',
    location TEXT,
    views_count INT NOT NULL DEFAULT 0,
    featured BOOLEAN NOT NULL DEFAULT false,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.listings IS 'Stores all product and service listings.';

-- Create transactions table
CREATE TABLE public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    buyer_id UUID NOT NULL REFERENCES public.users(id),
    seller_id UUID NOT NULL REFERENCES public.users(id),
    listing_id UUID REFERENCES public.listings(id),
    amount NUMERIC(10, 2) NOT NULL,
    commission NUMERIC(10, 2) NOT NULL,
    voucher TEXT NOT NULL UNIQUE,
    status transaction_status NOT NULL DEFAULT 'pending',
    payment_method TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.transactions IS 'Records all transactions between users.';

-- Create loan_requests table
CREATE TABLE public.loan_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id),
    amount NUMERIC(10, 2) NOT NULL,
    reason TEXT,
    status loan_status NOT NULL DEFAULT 'pending',
    approved_by UUID REFERENCES public.users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.loan_requests IS 'Stores user requests for credit in X$.';

-- Function to handle loan amortization and balance updates from sales
CREATE OR REPLACE FUNCTION public.amortize_loan_on_sale()
RETURNS TRIGGER AS $$
DECLARE
    seller_debt NUMERIC;
    amortization_amount NUMERIC;
BEGIN
    -- Only run when a transaction is updated to 'completed'
    IF NEW.status = 'completed' AND OLD.status <> 'completed' THEN
        -- Get seller's current debt
        SELECT debt_xs INTO seller_debt FROM public.users WHERE id = NEW.seller_id;

        -- If seller has debt, use the sale amount to pay it off
        IF seller_debt > 0 THEN
            amortization_amount := LEAST(NEW.amount, seller_debt);

            -- Decrease debt
            UPDATE public.users
            SET debt_xs = debt_xs - amortization_amount
            WHERE id = NEW.seller_id;

            -- Add any remaining amount to the seller's balance
            IF NEW.amount > amortization_amount THEN
                UPDATE public.users
                SET balance_xs = balance_xs + (NEW.amount - amortization_amount)
                WHERE id = NEW.seller_id;
            END IF;
        ELSE
            -- If no debt, add the full amount to the seller's balance
            UPDATE public.users
            SET balance_xs = balance_xs + NEW.amount
            WHERE id = NEW.seller_id;
        END IF;

        -- Update buyer's balance
        UPDATE public.users
        SET balance_xs = balance_xs - NEW.amount
        WHERE id = NEW.buyer_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
ALTER FUNCTION public.amortize_loan_on_sale() SET search_path = public;

-- Trigger for loan amortization
CREATE TRIGGER on_transaction_completed
AFTER UPDATE ON public.transactions
FOR EACH ROW
EXECUTE FUNCTION public.amortize_loan_on_sale();

-- Function to create an admin user
CREATE OR REPLACE FUNCTION public.create_admin_user(admin_email text)
RETURNS void AS $$
DECLARE
    user_id_to_update UUID;
BEGIN
    SELECT id INTO user_id_to_update FROM auth.users WHERE email = admin_email;
    IF user_id_to_update IS NOT NULL THEN
        UPDATE public.users
        SET role = 'admin', status = 'approved'
        WHERE id = user_id_to_update;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
ALTER FUNCTION public.create_admin_user(admin_email text) SET search_path = public;

-- Step 3: Enable RLS and define policies.
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loan_requests ENABLE ROW LEVEL SECURITY;

-- Policies for users table
CREATE POLICY "Users can view their own profile" ON public.users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update their own profile" ON public.users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admins can manage all users" ON public.users FOR ALL USING ((SELECT role FROM public.users WHERE id = auth.uid()) = 'admin');

-- Policies for categories table
CREATE POLICY "All users can view categories" ON public.categories FOR SELECT USING (true);
CREATE POLICY "Admins can manage categories" ON public.categories FOR ALL USING ((SELECT role FROM public.users WHERE id = auth.uid()) = 'admin');

-- Policies for listings table
CREATE POLICY "All users can view active listings" ON public.listings FOR SELECT USING (status = 'active');
CREATE POLICY "Users can manage their own listings" ON public.listings FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Admins can manage all listings" ON public.listings FOR ALL USING ((SELECT role FROM public.users WHERE id = auth.uid()) = 'admin');

-- Policies for transactions table
CREATE POLICY "Users can view their own transactions" ON public.transactions FOR SELECT USING (auth.uid() = buyer_id OR auth.uid() = seller_id);
CREATE POLICY "Users can create transactions" ON public.transactions FOR INSERT WITH CHECK (auth.uid() = buyer_id);
CREATE POLICY "Sellers can update transaction status" ON public.transactions FOR UPDATE USING (auth.uid() = seller_id);
CREATE POLICY "Admins can manage all transactions" ON public.transactions FOR ALL USING ((SELECT role FROM public.users WHERE id = auth.uid()) = 'admin');

-- Policies for loan_requests table
CREATE POLICY "Users can manage their own loan requests" ON public.loan_requests FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Admins can manage all loan requests" ON public.loan_requests FOR ALL USING ((SELECT role FROM public.users WHERE id = auth.uid()) = 'admin');

-- Insert some sample categories
INSERT INTO public.categories (name, description, icon, color) VALUES
('Serviços Profissionais', 'Consultoria, design, programação, etc.', 'briefcase', '#3b82f6'),
('Produtos Eletrónicos', 'Computadores, telemóveis, acessórios, etc.', 'cpu', '#ef4444'),
('Casa e Jardim', 'Mobiliário, decoração, ferramentas, etc.', 'home', '#22c55e'),
('Automóveis e Peças', 'Veículos, peças, serviços de mecânica, etc.', 'car', '#8b5cf6'),
('Formação e Educação', 'Cursos, workshops, explicações, etc.', 'book-open', '#f97316'),
('Saúde e Bem-estar', 'Terapias, massagens, produtos naturais, etc.', 'heart-pulse', '#14b8a6')
ON CONFLICT (name) DO NOTHING;
