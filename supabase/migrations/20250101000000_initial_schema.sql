-- XPermutas.com - Script de Migração Inicial Completo
-- Versão: 1.0
-- Descrição: Este script apaga toda a estrutura existente e recria a base de dados do zero.
-- Inclui tabelas, tipos, funções, triggers e políticas de segurança (RLS).

-- Fase 1: Limpeza Agressiva de Estruturas Antigas
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
DROP TYPE IF EXISTS public.loan_status CASCADE;

-- Fase 2: Criação de Tipos (ENUMs)
CREATE TYPE public.user_status AS ENUM ('pending', 'approved', 'rejected', 'suspended');
CREATE TYPE public.user_role AS ENUM ('user', 'admin');
CREATE TYPE public.listing_status AS ENUM ('active', 'sold', 'inactive');
CREATE TYPE public.transaction_status AS ENUM ('pending', 'completed', 'cancelled');
CREATE TYPE public.loan_status AS ENUM ('pending', 'approved', 'rejected');

-- Fase 3: Criação de Funções Auxiliares
CREATE OR REPLACE FUNCTION public.generate_unique_referral_code()
RETURNS TEXT AS $$
DECLARE
  new_code TEXT;
  found TEXT;
BEGIN
  LOOP
    new_code := upper(substr(md5(random()::text), 0, 7));
    SELECT referral_code INTO found FROM public.users WHERE referral_code = new_code;
    IF found IS NULL THEN
      RETURN new_code;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- Fase 4: Criação de Tabelas
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
    referral_code TEXT UNIQUE NOT NULL DEFAULT public.generate_unique_referral_code(),
    referred_by UUID REFERENCES public.users(id),
    profile_image_url TEXT,
    company_name TEXT,
    address TEXT,
    location TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.users IS 'Stores user profile information.';

CREATE TABLE public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    icon TEXT,
    color TEXT,
    parent_id UUID REFERENCES public.categories(id),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.categories IS 'Stores listing categories.';

CREATE TABLE public.listings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
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
COMMENT ON TABLE public.listings IS 'Stores all product and service listings.';

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
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ
);
COMMENT ON TABLE public.transactions IS 'Records all transactions between users.';

CREATE TABLE public.loan_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL,
    reason TEXT,
    status loan_status NOT NULL DEFAULT 'pending',
    approved_by UUID REFERENCES public.users(id),
    approved_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.loan_requests IS 'Stores user requests for credit in X$.';

-- Fase 5: Criação de Funções de Lógica de Negócio e Triggers
CREATE OR REPLACE FUNCTION public.handle_seller_on_transaction_complete()
RETURNS TRIGGER AS $$
DECLARE
  seller_debt NUMERIC;
  amortization_amount NUMERIC;
BEGIN
  -- Apenas executa a lógica quando a transação é ATUALIZADA para 'completed'
  IF TG_OP = 'UPDATE' AND NEW.status = 'completed' AND OLD.status != 'completed' THEN
    -- Obtém a dívida atual do vendedor
    SELECT debt_xs INTO seller_debt FROM public.users WHERE id = NEW.seller_id;

    IF seller_debt > 0 THEN
      -- Calcula o valor a amortizar
      amortization_amount := LEAST(NEW.amount, seller_debt);

      -- Atualiza a dívida do vendedor
      UPDATE public.users
      SET debt_xs = debt_xs - amortization_amount
      WHERE id = NEW.seller_id;

      -- Se ainda sobrar valor da venda, adiciona ao saldo X$
      IF NEW.amount > amortization_amount THEN
        UPDATE public.users
        SET balance_xs = balance_xs + (NEW.amount - amortization_amount)
        WHERE id = NEW.seller_id;
      END IF;
    ELSE
      -- Se não há dívida, todo o valor da venda vai para o saldo X$
      UPDATE public.users
      SET balance_xs = balance_xs + NEW.amount
      WHERE id = NEW.seller_id;
    END IF;

    -- Atualiza o saldo do comprador
    UPDATE public.users
    SET balance_xs = balance_xs - NEW.amount
    WHERE id = NEW.buyer_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Configura o search_path para segurança
ALTER FUNCTION public.handle_seller_on_transaction_complete() SET search_path = public;

CREATE TRIGGER on_transaction_completed
AFTER UPDATE OF status ON public.transactions
FOR EACH ROW
EXECUTE FUNCTION public.handle_seller_on_transaction_complete();

CREATE OR REPLACE FUNCTION public.create_admin_user(admin_email TEXT)
RETURNS void AS $$
BEGIN
  UPDATE public.users
  SET role = 'admin'
  WHERE id = (SELECT id FROM auth.users WHERE email = admin_email);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Configura o search_path para segurança
ALTER FUNCTION public.create_admin_user(text) SET search_path = public;

-- Fase 6: Ativação da Segurança a Nível de Linha (RLS)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loan_requests ENABLE ROW LEVEL SECURITY;

-- Fase 7: Definição de Políticas de RLS
-- Tabela: users
CREATE POLICY "Allow admin full access on users" ON public.users FOR ALL USING (get_user_role() = 'admin');
CREATE POLICY "Allow users to view their own data" ON public.users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Allow users to update their own data" ON public.users FOR UPDATE USING (auth.uid() = id);

-- Tabela: categories
CREATE POLICY "Allow admin full access on categories" ON public.categories FOR ALL USING (get_user_role() = 'admin');
CREATE POLICY "Allow authenticated users to read categories" ON public.categories FOR SELECT USING (auth.role() = 'authenticated');

-- Tabela: listings
CREATE POLICY "Allow admin full access on listings" ON public.listings FOR ALL USING (get_user_role() = 'admin');
CREATE POLICY "Allow public read access to active listings" ON public.listings FOR SELECT USING (status = 'active');
CREATE POLICY "Allow users to insert their own listings" ON public.listings FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Allow users to update their own listings" ON public.listings FOR UPDATE USING (auth.uid() = user_id);

-- Tabela: transactions
CREATE POLICY "Allow admin full access on transactions" ON public.transactions FOR ALL USING (get_user_role() = 'admin');
CREATE POLICY "Allow involved users to see their transactions" ON public.transactions FOR SELECT USING (auth.uid() = buyer_id OR auth.uid() = seller_id);
CREATE POLICY "Allow buyers to create transactions" ON public.transactions FOR INSERT WITH CHECK (auth.uid() = buyer_id);
CREATE POLICY "Allow sellers to update transactions (e.g. validate voucher)" ON public.transactions FOR UPDATE USING (auth.uid() = seller_id);

-- Tabela: loan_requests
CREATE POLICY "Allow admin full access on loan_requests" ON public.loan_requests FOR ALL USING (get_user_role() = 'admin');
CREATE POLICY "Allow users to manage their own loan requests" ON public.loan_requests FOR ALL USING (auth.uid() = user_id);


-- Função auxiliar para obter o role do utilizador atual
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT AS $$
DECLARE
  user_role TEXT;
BEGIN
  SELECT role INTO user_role FROM public.users WHERE id = auth.uid();
  RETURN user_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Configura o search_path para segurança
ALTER FUNCTION public.get_user_role() SET search_path = public;
