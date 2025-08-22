import React, { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { Users, ShoppingBag, TrendingUp, AlertCircle } from 'lucide-react';

interface Stats {
  totalUsers: number;
  pendingUsers: number;
  totalListings: number;
  activeListings: number;
  totalTransactions: number;
  completedTransactions: number;
}

export function AdminDashboard() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    fetchStats();
  }, []);

  const fetchStats = async () => {
    setIsLoading(true);
    try {
      const [
        { count: totalUsers },
        { count: pendingUsers },
        { count: totalListings },
        { count: activeListings },
        { count: totalTransactions },
        { count: completedTransactions }
      ] = await Promise.all([
        supabase.from('users').select('*', { count: 'exact', head: true }),
        supabase.from('users').select('*', { count: 'exact', head: true }).eq('status', 'pending'),
        supabase.from('listings').select('*', { count: 'exact', head: true }),
        supabase.from('listings').select('*', { count: 'exact', head: true }).eq('status', 'active'),
        supabase.from('transactions').select('*', { count: 'exact', head: true }),
        supabase.from('transactions').select('*', { count: 'exact', head: true }).eq('status', 'completed'),
      ]);

      setStats({
        totalUsers: totalUsers || 0,
        pendingUsers: pendingUsers || 0,
        totalListings: totalListings || 0,
        activeListings: activeListings || 0,
        totalTransactions: totalTransactions || 0,
        completedTransactions: completedTransactions || 0,
      });
    } catch (error) {
      console.error("Error fetching admin stats:", error);
    } finally {
      setIsLoading(false);
    }
  };

  const statCards = [
    { title: 'Total de Utilizadores', value: stats?.totalUsers, icon: Users, color: 'bg-blue-500' },
    { title: 'Aprovações Pendentes', value: stats?.pendingUsers, icon: AlertCircle, color: 'bg-yellow-500' },
    { title: 'Total de Anúncios', value: stats?.totalListings, icon: ShoppingBag, color: 'bg-green-500' },
    { title: 'Total de Transações', value: stats?.totalTransactions, icon: TrendingUp, color: 'bg-purple-500' },
  ];

  return (
    <div>
      <h1 className="text-2xl font-bold text-gray-800 mb-6">Dashboard</h1>
      {isLoading ? (
        <p>A carregar estatísticas...</p>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {statCards.map((card, index) => (
            <div key={index} className="bg-white p-6 rounded-lg shadow-md">
              <div className="flex items-center">
                <div className={`p-3 rounded-full text-white ${card.color}`}>
                  <card.icon className="w-6 h-6" />
                </div>
                <div className="ml-4">
                  <p className="text-sm text-gray-500">{card.title}</p>
                  <p className="text-2xl font-bold text-gray-800">{card.value}</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
      {/* Add more dashboard components here, like charts or recent activity feeds */}
    </div>
  );
}
