/*
# XPermutas Platform Database Schema
Complete database structure for the Portuguese multilateral exchange platform

## Query Description: 
This migration creates the complete database schema for XPermutas.com platform including:
- User management with approval workflow
- Marketplace listings system
- Virtual currency (X$) transactions
- Loan/credit system with automatic amortization
- Referral program
- Admin panel functionality
- Row Level Security (RLS) for data protection

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "High"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- users: User profiles with approval status and financial balances
- categories: Product/service categories
- listings: Marketplace advertisements
- transactions: X$ transactions with voucher system
- loan_requests: Credit applications
- referrals: Referral tracking system
- user_sessions: Session management

## Security Implications:
- RLS Status: Enabled on all tables
- Policy Changes: Yes - comprehensive RLS policies
- Auth Requirements: Supabase Auth integration

## Performance Impact:
- Indexes: Multiple indexes for performance
- Triggers: Auto-update triggers for timestamps
- Estimated Impact: Minimal for new database
*/

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create custom types
CREATE TYPE user_status AS ENUM ('pending', 'approved', 'rejected', 'suspended');
CREATE TYPE user_role AS ENUM ('user', 'admin');
CREATE TYPE listing_status AS ENUM ('active', 'sold', 'inactive');
CREATE TYPE transaction_status AS ENUM ('pending', 'completed', 'cancelled');
CREATE TYPE loan_status AS ENUM ('pending', 'approved', 'rejected');

-- Users table (extends Supabase auth.users)
CREATE TABLE users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    nif VARCHAR(20) UNIQUE NOT NULL,
    whatsapp VARCHAR(20) NOT NULL,
    status user_status DEFAULT 'pending',
    role user_role DEFAULT 'user',
    balance_xs DECIMAL(10,2) DEFAULT 0.00,
    balance_bonus DECIMAL(10,2) DEFAULT 0.00,
    debt_xs DECIMAL(10,2) DEFAULT 0.00,
    referral_code VARCHAR(20) UNIQUE NOT NULL,
    referred_by UUID REFERENCES users(id),
    profile_image_url TEXT,
    company_name VARCHAR(255),
    address TEXT,
    location VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Categories table
CREATE TABLE categories (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon VARCHAR(50),
    color VARCHAR(7),
    parent_id UUID REFERENCES categories(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Listings table
CREATE TABLE listings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    category_id UUID REFERENCES categories(id),
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    images TEXT[] DEFAULT '{}',
    status listing_status DEFAULT 'active',
    location VARCHAR(255),
    views_count INTEGER DEFAULT 0,
    featured BOOLEAN DEFAULT false,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Transactions table
CREATE TABLE transactions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    buyer_id UUID REFERENCES users(id) NOT NULL,
    seller_id UUID REFERENCES users(id) NOT NULL,
    listing_id UUID REFERENCES listings(id),
    amount DECIMAL(10,2) NOT NULL,
    commission DECIMAL(10,2) NOT NULL,
    voucher VARCHAR(50) UNIQUE NOT NULL,
    status transaction_status DEFAULT 'pending',
    payment_method VARCHAR(50),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE
);

-- Loan requests table
CREATE TABLE loan_requests (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    reason TEXT NOT NULL,
    status loan_status DEFAULT 'pending',
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW') NOT NULL
);

-- Referrals table
CREATE TABLE referrals (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    referrer_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    referred_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    bonus_amount DECIMAL(10,2) DEFAULT 0.00,
    is_paid BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    paid_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(referrer_id, referred_id)
);

-- System settings table
CREATE TABLE system_settings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    key VARCHAR(100) UNIQUE NOT NULL,
    value TEXT NOT NULL,
    description TEXT,
    updated_by UUID REFERENCES users(id),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- User sessions for tracking (optional)
CREATE TABLE user_sessions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create indexes for performance
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_referral_code ON users(referral_code);
CREATE INDEX idx_listings_user_id ON listings(user_id);
CREATE INDEX idx_listings_category_id ON listings(category_id);
CREATE INDEX idx_listings_status ON listings(status);
CREATE INDEX idx_listings_created_at ON listings(created_at DESC);
CREATE INDEX idx_transactions_buyer_id ON transactions(buyer_id);
CREATE INDEX idx_transactions_seller_id ON transactions(seller_id);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_loan_requests_user_id ON loan_requests(user_id);
CREATE INDEX idx_loan_requests_status ON loan_requests(status);
CREATE INDEX idx_referrals_referrer_id ON referrals(referrer_id);
CREATE INDEX idx_referrals_referred_id ON referrals(referred_id);

-- Create functions for automatic updates
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at columns
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_listings_updated_at BEFORE UPDATE ON listings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to generate unique referral codes
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.referral_code IS NULL OR NEW.referral_code = '' THEN
        NEW.referral_code := UPPER(SUBSTRING(NEW.name FROM 1 FOR 4)) || 
                            TO_CHAR(EXTRACT(YEAR FROM NOW()), 'YYYY') ||
                            LPAD(FLOOR(RANDOM() * 1000)::TEXT, 3, '0');
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for automatic referral code generation
CREATE TRIGGER generate_referral_code_trigger BEFORE INSERT ON users
    FOR EACH ROW EXECUTE FUNCTION generate_referral_code();

-- Function to handle loan amortization
CREATE OR REPLACE FUNCTION process_transaction_amortization()
RETURNS TRIGGER AS $$
BEGIN
    -- If user has debt, automatically deduct from earnings
    IF NEW.status = 'completed' AND OLD.status = 'pending' THEN
        UPDATE users 
        SET 
            debt_xs = GREATEST(0, debt_xs - NEW.amount),
            balance_xs = CASE 
                WHEN debt_xs >= NEW.amount THEN balance_xs
                ELSE balance_xs + (NEW.amount - debt_xs)
            END
        WHERE id = NEW.seller_id;
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for automatic loan amortization
CREATE TRIGGER process_transaction_amortization_trigger AFTER UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION process_transaction_amortization();

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE loan_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for users
CREATE POLICY "Users can view their own profile" ON users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Admins can view all users" ON users
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- RLS Policies for categories
CREATE POLICY "Everyone can view categories" ON categories
    FOR SELECT USING (is_active = true);

CREATE POLICY "Admins can manage categories" ON categories
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- RLS Policies for listings
CREATE POLICY "Everyone can view active listings" ON listings
    FOR SELECT USING (status = 'active');

CREATE POLICY "Users can manage their own listings" ON listings
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage all listings" ON listings
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- RLS Policies for transactions
CREATE POLICY "Users can view their own transactions" ON transactions
    FOR SELECT USING (auth.uid() = buyer_id OR auth.uid() = seller_id);

CREATE POLICY "Users can create transactions as buyer" ON transactions
    FOR INSERT WITH CHECK (auth.uid() = buyer_id);

CREATE POLICY "Sellers can update transaction status" ON transactions
    FOR UPDATE USING (auth.uid() = seller_id);

CREATE POLICY "Admins can manage all transactions" ON transactions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- RLS Policies for loan requests
CREATE POLICY "Users can view their own loan requests" ON loan_requests
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own loan requests" ON loan_requests
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can manage all loan requests" ON loan_requests
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- RLS Policies for referrals
CREATE POLICY "Users can view their referrals" ON referrals
    FOR SELECT USING (auth.uid() = referrer_id OR auth.uid() = referred_id);

CREATE POLICY "System can create referrals" ON referrals
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Admins can manage all referrals" ON referrals
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- RLS Policies for system settings
CREATE POLICY "Admins can manage system settings" ON system_settings
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Insert default categories
INSERT INTO categories (name, description, icon, color) VALUES
('Tecnologia', 'Equipamentos e serviços tecnológicos', '💻', '#3B82F6'),
('Construção', 'Materiais e serviços de construção', '🏗️', '#F59E0B'),
('Automóvel', 'Veículos e peças automóveis', '🚗', '#EF4444'),
('Saúde', 'Equipamentos e serviços de saúde', '🏥', '#10B981'),
('Alimentação', 'Produtos alimentares e restauração', '🍽️', '#F97316'),
('Vestuário', 'Roupas e acessórios', '👔', '#8B5CF6'),
('Imobiliário', 'Propriedades e serviços imobiliários', '🏠', '#06B6D4'),
('Educação', 'Formação e serviços educativos', '📚', '#84CC16'),
('Marketing', 'Publicidade e marketing digital', '📈', '#EC4899'),
('Consultoria', 'Serviços de consultoria', '💼', '#6B7280');

-- Insert default system settings
INSERT INTO system_settings (key, value, description) VALUES
('referral_bonus_amount', '25.00', 'Valor do bónus de indicação em Euros'),
('commission_rate', '0.10', 'Taxa de comissão (10%)'),
('max_loan_amount', '1000.00', 'Valor máximo de empréstimo em X$'),
('platform_email', 'contacto@xpermutas.com', 'Email de contacto da plataforma'),
('platform_phone', '+351 210 000 000', 'Telefone de contacto da plataforma');

-- Create admin user function (to be called after auth user creation)
CREATE OR REPLACE FUNCTION create_admin_user(user_email TEXT)
RETURNS UUID AS $$
DECLARE
    admin_id UUID;
BEGIN
    -- Get the auth user ID
    SELECT id INTO admin_id FROM auth.users WHERE email = user_email;
    
    IF admin_id IS NOT NULL THEN
        -- Insert admin profile
        INSERT INTO users (
            id, name, nif, whatsapp, status, role, 
            referral_code, created_at
        ) VALUES (
            admin_id, 'Administrador XPermutas', '000000000', 
            '+351900000000', 'approved', 'admin',
            'ADMIN2025', NOW()
        ) ON CONFLICT (id) DO UPDATE SET
            role = 'admin',
            status = 'approved';
            
        RETURN admin_id;
    END IF;
    
    RETURN NULL;
END;
$$ language 'plpgsql' SECURITY DEFINER;
