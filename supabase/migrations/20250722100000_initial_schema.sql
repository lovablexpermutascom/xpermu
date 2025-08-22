/*
  XPermutas.com - Esquema Inicial da Base de Dados
  Versão: 2.0
  Data: 2025-07-22
  Descrição:
  Este script cria a estrutura completa da base de dados para a plataforma XPermutas.com.
  Inclui tabelas para utilizadores, anúncios, transações, categorias e pedidos de empréstimo.
  Também configura tipos personalizados, funções, triggers para automação e políticas de segurança (RLS).

  Correções nesta versão:
  - Corrigido erro de sintaxe no valor padrão de timestamps.
  - Corrigido erro "missing FROM-clause entry for table 'old'" no trigger de transações,
    melhorando a lógica para lidar com operações de INSERT e UPDATE.
*/

--==============================================================
-- 1. TIPOS PERSONALIZADOS (ENUMS)
--==============================================================
-- Define os possíveis estados de um utilizador
CREATE TYPE public.user_status AS ENUM ('pending', 'approved', 'rejected', 'suspended');
-- Define as possíveis funções de um utilizador
CREATE TYPE public.user_role AS ENUM ('user', 'admin');
-- Define os possíveis estados de um anúncio
CREATE TYPE public.listing_status AS ENUM ('active', 'sold', 'inactive');
-- Define os possíveis estados de uma transação
CREATE TYPE public.transaction_status AS ENUM ('pending', 'completed', 'cancelled');
-- Define os possíveis estados de um pedido de empréstimo
CREATE TYPE public.loan_status AS ENUM ('pending', 'approved', 'rejected');

--==============================================================
-- 2. FUNÇÕES AUXILIARES
--==============================================================
/*
  Função para gerar um código de referência aleatório.
  Usado como valor padrão na tabela de utilizadores.
*/
CREATE OR REPLACE FUNCTION public.generate_referral_code(length integer)
RETURNS text AS $$
DECLARE
  chars text[] := '{A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,0,1,2,3,4,5,6,7,8,9}';
  result text := '';
  i integer := 0;
BEGIN
  IF length < 1 THEN
    raise exception 'O comprimento do código deve ser pelo menos 1.';
  END IF;
  FOR i IN 1..length LOOP
    result := result || chars[1+random()*(array_length(chars, 1)-1)];
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

/*
  Função para atualizar o campo 'updated_at' automaticamente.
  Usado em triggers.
*/
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = now(); 
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--==============================================================
-- 3. TABELAS PRINCIPAIS
--==============================================================
-- Tabela de Utilizadores (Perfis)
-- Armazena dados públicos e da aplicação para cada utilizador.
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
  referral_code text UNIQUE NOT NULL DEFAULT public.generate_referral_code(8),
  referred_by uuid REFERENCES public.users(id),
  profile_image_url text,
  company_name text,
  address text,
  location text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.users IS 'Tabela de perfis que estende a informação de auth.users.';

-- Tabela de Categorias para os Anúncios
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
COMMENT ON TABLE public.categories IS 'Categorias para organizar os anúncios do marketplace.';

-- Tabela de Anúncios (Listings)
CREATE TABLE public.listings (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  category_id uuid REFERENCES public.categories(id),
  title text NOT NULL,
  description text,
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
COMMENT ON TABLE public.listings IS 'Anúncios de produtos ou serviços no marketplace.';

-- Tabela de Transações
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
  completed_at timestamptz
);
COMMENT ON TABLE public.transactions IS 'Registo de todas as transações de permuta.';

-- Tabela de Pedidos de Empréstimo
CREATE TABLE public.loan_requests (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id),
  amount numeric(10, 2) NOT NULL,
  reason text,
  status loan_status NOT NULL DEFAULT 'pending',
  approved_by uuid REFERENCES public.users(id),
  approved_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.loan_requests IS 'Pedidos de linha de crédito em X$ pelos utilizadores.';


--==============================================================
-- 4. TRIGGERS
--==============================================================
-- Trigger para atualizar 'updated_at' na tabela de utilizadores
CREATE TRIGGER set_users_updated_at
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Trigger para atualizar 'updated_at' na tabela de anúncios
CREATE TRIGGER set_listings_updated_at
BEFORE UPDATE ON public.listings
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Lógica de Amortização de Empréstimo
/*
  Esta função é acionada sempre que uma transação é criada ou atualizada.
  Se o estado da transação se tornar 'completed', a função verifica se o vendedor
  tem alguma dívida de empréstimo. Se tiver, 100% do valor da venda é usado
  para abater essa dívida. O valor remanescente, se houver, é adicionado ao saldo X$ do vendedor.
  Se não houver dívida, o valor total da venda é adicionado ao saldo X$.
  
  A verificação `NEW.status = 'completed' AND (TG_OP = 'INSERT' OR NEW.status IS DISTINCT FROM OLD.status)`
  garante que a lógica só corre uma vez, no momento exato em que a transação é finalizada,
  e previne erros ao lidar corretamente com operações de INSERT e UPDATE.
*/
CREATE OR REPLACE FUNCTION public.handle_seller_on_transaction_complete()
RETURNS TRIGGER AS $$
DECLARE
  seller_current_debt NUMERIC;
  amortization_amount NUMERIC;
  remaining_sale_amount NUMERIC;
BEGIN
  -- Corre apenas quando a transação é marcada como 'completed' pela primeira vez.
  IF NEW.status = 'completed' AND (TG_OP = 'INSERT' OR NEW.status IS DISTINCT FROM OLD.status) THEN
    
    -- Obtém a dívida atual do vendedor
    SELECT debt_xs INTO seller_current_debt FROM public.users WHERE id = NEW.seller_id;
    
    -- Se o vendedor tiver dívida, usa o valor da venda para amortizar
    IF seller_current_debt > 0 THEN
      amortization_amount := LEAST(seller_current_debt, NEW.amount);
      remaining_sale_amount := NEW.amount - amortization_amount;
      
      -- Atualiza a dívida e o saldo do vendedor
      UPDATE public.users
      SET 
        debt_xs = debt_xs - amortization_amount,
        balance_xs = balance_xs + remaining_sale_amount
      WHERE id = NEW.seller_id;
      
    ELSE
      -- Se não houver dívida, o valor total da venda vai para o saldo do vendedor
      UPDATE public.users
      SET balance_xs = balance_xs + NEW.amount
      WHERE id = NEW.seller_id;
    END IF;

    -- Atualiza a data de conclusão da transação
    NEW.completed_at := now();
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger que aciona a função de amortização na tabela de transações
CREATE TRIGGER on_transaction_completed
BEFORE INSERT OR UPDATE ON public.transactions
FOR EACH ROW
EXECUTE FUNCTION public.handle_seller_on_transaction_complete();


--==============================================================
-- 5. FUNÇÃO DE ADMINISTRAÇÃO
--==============================================================
/*
  Função para promover um utilizador a administrador.
  Deve ser executada manualmente pelo super-administrador no editor SQL do Supabase.
  Exemplo: SELECT create_admin_user('admin@exemplo.com');
*/
CREATE OR REPLACE FUNCTION public.create_admin_user(admin_email TEXT)
RETURNS TEXT AS $$
DECLARE
  user_id UUID;
BEGIN
  -- Encontra o ID do utilizador com base no email
  SELECT id INTO user_id FROM auth.users WHERE email = admin_email;
  
  IF user_id IS NULL THEN
    RETURN 'Erro: Utilizador não encontrado.';
  END IF;
  
  -- Atualiza a função do utilizador para 'admin'
  UPDATE public.users
  SET role = 'admin'
  WHERE id = user_id;
  
  RETURN 'Sucesso: Utilizador ' || admin_email || ' promovido a admin.';
EXCEPTION
  WHEN OTHERS THEN
    RETURN 'Erro inesperado ao tentar promover utilizador.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


--==============================================================
-- 6. POLÍTICAS DE SEGURANÇA (ROW LEVEL SECURITY - RLS)
--==============================================================
-- Ativar RLS em todas as tabelas
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loan_requests ENABLE ROW LEVEL SECURITY;

-- Políticas para a tabela 'users'
CREATE POLICY "Utilizadores podem ver os seus próprios dados" ON public.users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Utilizadores podem atualizar os seus próprios dados" ON public.users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admins têm acesso total aos utilizadores" ON public.users FOR ALL USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));
CREATE POLICY "Permitir leitura de dados públicos de outros utilizadores" ON public.users FOR SELECT USING (true); -- Ajustar se necessário para maior restrição

-- Políticas para a tabela 'categories'
CREATE POLICY "Qualquer pessoa pode ver as categorias" ON public.categories FOR SELECT USING (true);
CREATE POLICY "Admins podem gerir categorias" ON public.categories FOR ALL USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- Políticas para a tabela 'listings'
CREATE POLICY "Qualquer pessoa pode ver anúncios ativos" ON public.listings FOR SELECT USING (status = 'active');
CREATE POLICY "Utilizadores podem gerir os seus próprios anúncios" ON public.listings FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Admins têm acesso total aos anúncios" ON public.listings FOR ALL USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- Políticas para a tabela 'transactions'
CREATE POLICY "Utilizadores podem ver as suas próprias transações" ON public.transactions FOR SELECT USING (auth.uid() = buyer_id OR auth.uid() = seller_id);
CREATE POLICY "Admins têm acesso total às transações" ON public.transactions FOR ALL USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- Políticas para a tabela 'loan_requests'
CREATE POLICY "Utilizadores podem ver e criar os seus próprios pedidos de empréstimo" ON public.loan_requests FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Admins têm acesso total aos pedidos de empréstimo" ON public.loan_requests FOR ALL USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

--==============================================================
-- FIM DO SCRIPT
--==============================================================
