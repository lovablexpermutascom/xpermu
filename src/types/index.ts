export interface User {
  id: string;
  name: string;
  email: string;
  nif: string;
  whatsapp: string;
  status: 'pending' | 'approved' | 'rejected' | 'suspended';
  balanceXS: number;
  balanceBonus: number;
  debtXS: number;
  referralCode: string;
  referredBy?: string;
  role: 'user' | 'admin';
  createdAt: Date;
}

export interface Listing {
  id: string;
  userId: string;
  title: string;
  description: string;
  price: number;
  category: string;
  images: string[];
  status: 'active' | 'sold' | 'inactive';
  location: string;
  createdAt: Date;
  user?: User;
}

export interface Transaction {
  id: string;
  buyerId: string;
  sellerId: string;
  listingId: string;
  amount: number;
  commission: number;
  voucher: string;
  status: 'pending' | 'completed' | 'cancelled';
  createdAt: Date;
  buyer?: User;
  seller?: User;
  listing?: Listing;
}

export interface LoanRequest {
  id: string;
  userId: string;
  amount: number;
  status: 'pending' | 'approved' | 'rejected';
  reason: string;
  createdAt: Date;
  user?: User;
}
