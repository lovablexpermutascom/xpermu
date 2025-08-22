/*
# [Initial Schema Setup - Corrected]
This script sets up the initial database schema for the XPermutas.com platform. It creates all necessary tables, custom types, functions, and Row Level Security (RLS) policies. This version corrects a syntax error in the timestamp default value.

## Query Description: This is a foundational script. It creates the entire structure for users, listings, transactions, and more. It is safe to run on a new, empty database. Running it on an existing database with conflicting table names will result in errors.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "High"
- Requires-Backup: false (for new databases)
- Reversible: false (requires manual dropping of all created objects)

## Structure Details:
- Tables created: users, categories, listings, transactions, loan_requests
- Custom Types: user_status, user_role, listing_status, transaction_status, loan_status
- Functions: generate_referral_code, create_admin_user, handle_debt_repayment
- Triggers: on_transaction_completed

## Security Implications:
- RLS Status: Enabled for all tables.
- Policy Changes: Yes, policies are created to restrict data access based on user roles and ownership.
- Auth Requirements: Relies on Supabase Auth (auth.users table).

## Performance Impact:
- Indexes: Added on foreign keys and frequently queried columns (e.g., user_id, status).
- Triggers: Added for automatic data management, which may have a minor performance impact on inserts/updates.
- Estimated Impact: Low on a new system, designed for scalability.
*/

-- 1. Custom Types
-- These types ensure data consistency for status and role fields across the application.

CREATE TYPE user_status AS ENUM ('pending', 'approved', 'rejected', 'suspended');
CREATE TYPE user_role AS ENUM ('user', 'admin');
CREATE TYPE listing_status AS ENUM ('active', 'sold', 'inactive');
CREATE TYPE transaction_status AS ENUM ('pending', 'completed', 'cancelled');
CREATE TYPE loan_status AS ENUM ('pending', 'approved', 'rejected');

-- 2. Helper Functions
-- These functions encapsulate business logic at the database level.

-- Function to generate a unique referral code
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS TEXT AS $$
DECLARE
  new_code TEXT;
  is_duplicate BOOLEAN;
BEGIN
  LOOP
    new_code := upper(substr(md5(random()::text), 0, 9)); -- 8-character random code
    SELECT EXISTS (SELECT 1 FROM users WHERE referral_code = new_code) INTO is_duplicate;
    IF NOT is_duplicate THEN
      RETURN new_code;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 3. Tables
-- The core data structures for the platform.

-- Users Table
-- Stores user profile information, linked to Supabase Auth.
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    nif TEXT NOT NULL UNIQUE CHECK (nif ~ '^[0-9]{9}$'),
    whatsapp TEXT NOT NULL UNIQUE CHECK (whatsapp ~ '^\+351[0-9]{9}$'),
    status user_status DEFAULT 'pending' NOT NULL,
    role user_role DEFAULT 'user' NOT NULL,
    balance_xs NUMERIC(12, 2) DEFAULT 0.00 NOT NULL,
    balance_bonus NUMERIC(12, 2) DEFAULT 0.00 NOT NULL,
    debt_xs NUMERIC(12, 2) DEFAULT 0.00 NOT NULL,
    referral_code TEXT UNIQUE DEFAULT generate_referral_code(),
    referred_by UUID REFERENCES users(id),
    profile_image_url TEXT,
    company_name TEXT,
    address TEXT,
    location TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);
COMMENT ON TABLE users IS 'Stores user profile information, financial data, and status.';

-- Categories Table
-- For organizing listings.
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    icon TEXT,
    color TEXT,
    parent_id UUID REFERENCES categories(id),
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);
COMMENT ON TABLE categories IS 'Stores categories for marketplace listings.';

-- Listings Table
-- Represents the products or services offered by users.
CREATE TABLE listings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id),
    title TEXT NOT NULL,
    description TEXT,
    price NUMERIC(12, 2) NOT NULL CHECK (price > 0),
    images TEXT[],
    status listing_status DEFAULT 'active' NOT NULL,
    location TEXT,
    views_count INT DEFAULT 0 NOT NULL,
    featured BOOLEAN DEFAULT false NOT NULL,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);
COMMENT ON TABLE listings IS 'Marketplace listings for products and services.';

-- Transactions Table
-- Records all exchanges between users.
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    buyer_id UUID NOT NULL REFERENCES users(id),
    seller_id UUID NOT NULL REFERENCES users(id),
    listing_id UUID REFERENCES listings(id),
    amount NUMERIC(12, 2) NOT NULL,
    commission NUMERIC(12, 2) NOT NULL,
    voucher TEXT NOT NULL UNIQUE,
    status transaction_status DEFAULT 'pending' NOT NULL,
    payment_method TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    completed_at TIMESTAMPTZ,
    CONSTRAINT buyer_seller_check CHECK (buyer_id <> seller_id)
);
COMMENT ON TABLE transactions IS 'Records all financial transactions on the platform.';

-- Loan Requests Table
-- Tracks user requests for credit in X$.
CREATE TABLE loan_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    reason TEXT,
    status loan_status DEFAULT 'pending' NOT NULL,
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);
COMMENT ON TABLE loan_requests IS 'Manages user requests for X$ credit lines.';

-- 4. Triggers and Automation
-- Automates repetitive tasks like setting up new user profiles.

-- Function to handle debt repayment automatically
CREATE OR REPLACE FUNCTION handle_debt_repayment()
RETURNS TRIGGER AS $$
DECLARE
  seller_debt NUMERIC;
  repayment_amount NUMERIC;
BEGIN
  -- Check if the transaction is completed
  IF NEW.status = 'completed' AND OLD.status <> 'completed' THEN
    -- Get the seller's current debt
    SELECT debt_xs INTO seller_debt FROM users WHERE id = NEW.seller_id;

    -- If the seller has debt, use the transaction amount to repay it
    IF seller_debt > 0 THEN
      -- Determine the amount to repay
      repayment_amount := LEAST(NEW.amount, seller_debt);

      -- Update seller's debt and balance
      UPDATE users
      SET
        debt_xs = debt_xs - repayment_amount,
        balance_xs = balance_xs + (NEW.amount - repayment_amount)
      WHERE id = NEW.seller_id;
    ELSE
      -- If no debt, just add the amount to the seller's balance
      UPDATE users
      SET balance_xs = balance_xs + NEW.amount
      WHERE id = NEW.seller_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to call the debt repayment function after a transaction is completed
CREATE TRIGGER on_transaction_completed
  AFTER UPDATE OF status ON transactions
  FOR EACH ROW
  EXECUTE PROCEDURE handle_debt_repayment();

-- Function to create an admin user
CREATE OR REPLACE FUNCTION create_admin_user(admin_email TEXT)
RETURNS TEXT AS $$
DECLARE
  user_id UUID;
BEGIN
  -- Find user_id from auth.users based on email
  SELECT id INTO user_id FROM auth.users WHERE email = admin_email;

  IF user_id IS NULL THEN
    RETURN 'Error: User with that email not found in auth.users.';
  END IF;

  -- Update the user's role to 'admin' in the public.users table
  UPDATE public.users
  SET role = 'admin'
  WHERE id = user_id;

  IF NOT FOUND THEN
    RETURN 'Error: User profile not found in public.users. The profile must be created first.';
  END IF;

  RETURN 'Success: User ' || admin_email || ' is now an admin.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 5. Row Level Security (RLS)
-- Secures data by ensuring users can only access what they're allowed to.

-- Enable RLS for all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE loan_requests ENABLE ROW LEVEL SECURITY;

-- Policies for 'users' table
CREATE POLICY "Users can view their own profile" ON users
  FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update their own profile" ON users
  FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admins can manage all user profiles" ON users
  FOR ALL USING (
    (SELECT role FROM users WHERE id = auth.uid()) = 'admin'
  ) WITH CHECK (
    (SELECT role FROM users WHERE id = auth.uid()) = 'admin'
  );

-- Policies for 'categories' table
CREATE POLICY "All users can view categories" ON categories
  FOR SELECT USING (true);
CREATE POLICY "Admins can manage categories" ON categories
  FOR ALL USING (
    (SELECT role FROM users WHERE id = auth.uid()) = 'admin'
  ) WITH CHECK (
    (SELECT role FROM users WHERE id = auth.uid()) = 'admin'
  );

-- Policies for 'listings' table
CREATE POLICY "All users can view active listings" ON listings
  FOR SELECT USING (status = 'active');
CREATE POLICY "Users can view their own listings" ON listings
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create listings" ON listings
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own listings" ON listings
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Admins can manage all listings" ON listings
  FOR ALL USING (
    (SELECT role FROM users WHERE id = auth.uid()) = 'admin'
  ) WITH CHECK (
    (SELECT role FROM users WHERE id = auth.uid()) = 'admin'
  );

-- Policies for 'transactions' table
CREATE POLICY "Users can view their own transactions" ON transactions
  FOR SELECT USING (auth.uid() = buyer_id OR auth.uid() = seller_id);
CREATE POLICY "Users can create transactions" ON transactions
  FOR INSERT WITH CHECK (auth.uid() = buyer_id);
CREATE POLICY "Sellers can update transaction status" ON transactions
  FOR UPDATE USING (auth.uid() = seller_id) WITH CHECK (status <> OLD.status);
CREATE POLICY "Admins can manage all transactions" ON transactions
  FOR ALL USING (
    (SELECT role FROM users WHERE id = auth.uid()) = 'admin'
  ) WITH CHECK (
    (SELECT role FROM users WHERE id = auth.uid()) = 'admin'
  );

-- Policies for 'loan_requests' table
CREATE POLICY "Users can view their own loan requests" ON loan_requests
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create loan requests" ON loan_requests
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins can manage all loan requests" ON loan_requests
  FOR ALL USING (
    (SELECT role FROM users WHERE id = auth.uid()) = 'admin'
  ) WITH CHECK (
    (SELECT role FROM users WHERE id = auth.uid()) = 'admin'
  );

-- 6. Indexes
-- Improves query performance on frequently accessed columns.

CREATE INDEX idx_listings_user_id ON listings(user_id);
CREATE INDEX idx_listings_category_id ON listings(category_id);
CREATE INDEX idx_listings_status ON listings(status);
CREATE INDEX idx_transactions_buyer_id ON transactions(buyer_id);
CREATE INDEX idx_transactions_seller_id ON transactions(seller_id);
CREATE INDEX idx_loan_requests_user_id ON loan_requests(user_id);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_role ON users(role);
