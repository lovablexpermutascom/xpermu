import React, { createContext, useContext, useState, useEffect } from 'react';
import { supabase, DatabaseUser } from '../lib/supabase';
import { User as SupabaseUser } from '@supabase/supabase-js';

interface AuthContextType {
  user: DatabaseUser | null;
  supabaseUser: SupabaseUser | null;
  login: (email: string, password: string) => Promise<{ success: boolean; error?: string }>;
  register: (userData: RegisterData) => Promise<{ success: boolean; error?: string }>;
  logout: () => Promise<void>;
  isLoading: boolean;
}

interface RegisterData {
  name: string;
  email: string;
  password: string;
  nif: string;
  whatsapp: string;
  referralCode?: string;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<DatabaseUser | null>(null);
  const [supabaseUser, setSupabaseUser] = useState<SupabaseUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Get initial session
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session?.user) {
        setSupabaseUser(session.user);
        fetchUserProfile(session.user.id);
      } else {
        setIsLoading(false);
      }
    });

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      async (event, session) => {
        if (session?.user) {
          setSupabaseUser(session.user);
          await fetchUserProfile(session.user.id);
        } else {
          setSupabaseUser(null);
          setUser(null);
          setIsLoading(false);
        }
      }
    );

    return () => subscription.unsubscribe();
  }, []);

  const fetchUserProfile = async (userId: string) => {
    try {
      const { data, error } = await supabase
        .from('users')
        .select('*')
        .eq('id', userId)
        .single();

      if (error) {
        console.error('Error fetching user profile:', error);
        setIsLoading(false);
        return;
      }

      setUser(data);
    } catch (error) {
      console.error('Error:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const login = async (email: string, password: string) => {
    setIsLoading(true);
    
    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password
      });

      if (error) {
        setIsLoading(false);
        return { success: false, error: error.message };
      }

      if (data.user) {
        // Check if user profile exists and is approved
        const { data: userProfile, error: profileError } = await supabase
          .from('users')
          .select('*')
          .eq('id', data.user.id)
          .single();

        if (profileError || !userProfile) {
          await supabase.auth.signOut();
          setIsLoading(false);
          return { success: false, error: 'Perfil de utilizador não encontrado' };
        }

        if (userProfile.status !== 'approved') {
          await supabase.auth.signOut();
          setIsLoading(false);
          return { success: false, error: 'Conta ainda não aprovada ou foi suspensa' };
        }

        setUser(userProfile);
        setIsLoading(false);
        return { success: true };
      }

      setIsLoading(false);
      return { success: false, error: 'Erro desconhecido' };
    } catch (error) {
      setIsLoading(false);
      return { success: false, error: 'Erro de conexão' };
    }
  };

  const register = async (userData: RegisterData) => {
    setIsLoading(true);
    
    try {
      // Check if email or NIF already exists
      const { data: existingUser } = await supabase
        .from('users')
        .select('id, nif')
        .or(`nif.eq.${userData.nif}`)
        .limit(1);

      if (existingUser && existingUser.length > 0) {
        setIsLoading(false);
        return { success: false, error: 'NIF já registado' };
      }

      // Find referrer ID if code is provided
      let referrerId: string | undefined = undefined;
      if (userData.referralCode) {
        const { data: referrer, error: referrerError } = await supabase
          .from('users')
          .select('id')
          .eq('referral_code', userData.referralCode.trim().toUpperCase())
          .single();

        if (referrerError || !referrer) {
            setIsLoading(false);
            return { success: false, error: 'Código de indicação inválido' };
        }
        referrerId = referrer.id;
      }

      // Create auth user
      const { data, error } = await supabase.auth.signUp({
        email: userData.email,
        password: userData.password,
        options: {
          emailRedirectTo: `${window.location.origin}/`
        }
      });

      if (error) {
        setIsLoading(false);
        return { success: false, error: error.message };
      }

      if (data.user) {
        // Create user profile
        const { error: profileError } = await supabase
          .from('users')
          .insert({
            id: data.user.id,
            name: userData.name,
            nif: userData.nif,
            whatsapp: userData.whatsapp,
            status: 'pending',
            role: 'user',
            referred_by: referrerId,
          });

        if (profileError) {
          console.error('Profile creation error:', profileError);
          // Attempt to delete the auth user if profile creation fails
          await supabase.auth.admin.deleteUser(data.user.id);
          setIsLoading(false);
          return { success: false, error: 'Erro ao criar perfil' };
        }

        // Sign out immediately after registration
        await supabase.auth.signOut();
        
        setIsLoading(false);
        return { success: true };
      }

      setIsLoading(false);
      return { success: false, error: 'Erro ao criar conta' };
    } catch (error) {
      setIsLoading(false);
      return { success: false, error: 'Erro de conexão' };
    }
  };

  const logout = async () => {
    await supabase.auth.signOut();
    setUser(null);
    setSupabaseUser(null);
  };

  return (
    <AuthContext.Provider value={{ 
      user, 
      supabaseUser,
      login, 
      register, 
      logout, 
      isLoading 
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
