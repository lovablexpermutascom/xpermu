import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables');
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true
  }
});

// Database types
export interface DatabaseUser {
  id: string;
  name: string;
  nif: string;
  whatsapp: string;
  status: 'pending' | 'approved' | 'rejected' | 'suspended';
  role: 'user' | 'admin';
  balance_xs: number;
  balance_bonus: number;
  debt_xs: number;
  referral_code: string;
  referred_by?: string;
  profile_image_url?: string;
  company_name?: string;
  address?: string;
  location?: string;
  created_at: string;
  updated_at: string;
}

export interface DatabaseListing {
  id: string;
  user_id: string;
  category_id?: string;
  title: string;
  description: string;
  price: number;
  images: string[];
  status: 'active' | 'sold' | 'inactive';
  location?: string;
  views_count: number;
  featured: boolean;
  expires_at?: string;
  created_at: string;
  updated_at: string;
  users?: DatabaseUser;
  categories?: {
    id: string;
    name: string;
    icon?: string;
    color?: string;
  };
}

export interface DatabaseTransaction {
  id: string;
  buyer_id: string;
  seller_id: string;
  listing_id?: string;
  amount: number;
  commission: number;
  voucher: string;
  status: 'pending' | 'completed' | 'cancelled';
  payment_method?: string;
  notes?: string;
  created_at: string;
  completed_at?: string;
  buyer?: DatabaseUser;
  seller?: DatabaseUser;
  listings?: DatabaseListing;
}

export interface DatabaseLoanRequest {
  id: string;
  user_id: string;
  amount: number;
  reason: string;
  status: 'pending' | 'approved' | 'rejected';
  approved_by?: string;
  approved_at?: string;
  notes?: string;
  created_at: string;
  users?: DatabaseUser;
}

export interface DatabaseCategory {
  id: string;
  name: string;
  description?: string;
  icon?: string;
  color?: string;
  parent_id?: string;
  is_active: boolean;
  created_at: string;
}
