import React, { useEffect, useState } from 'react';
import { Wallet, TrendingUp, Users, ShoppingBag, CreditCard, Gift, AlertCircle } from 'lucide-react';
import { motion } from 'framer-motion';
import { useAuth } from '../context/AuthContext';
import { supabase, DatabaseListing, DatabaseTransaction } from '../lib/supabase';
import { GlassCard } from '../components/ui/GlassCard';
import { Link } from 'react-router-dom';

export function Dashboard() {
  const { user } = useAuth();
  const [listings, setListings] = useState<DatabaseListing[]>([]);
  const [transactions, setTransactions] = useState<DatabaseTransaction[]>([]);
  const [isLoadingData, setIsLoadingData] = useState(true);

  useEffect(() => {
    if (user) {
      loadDashboardData();
    }
  }, [user]);

  const loadDashboardData = async () => {
    try {
      setIsLoadingData(true);
      
      // Load user's listings
      const { data: listingsData } = await supabase
        .from('listings')
        .select(`
          *,
          categories(name, icon, color)
        `)
        .eq('user_id', user?.id)
        .order('created_at', { ascending: false })
        .limit(5);

      // Load user's transactions
      const { data: transactionsData } = await supabase
        .from('transactions')
        .select(`
          *,
          buyer:buyer_id(name),
          seller:seller_id(name),
          listings(title)
        `)
        .or(`buyer_id.eq.${user?.id},seller_id.eq.${user?.id}`)
        .order('created_at', { ascending: false })
        .limit(5);

      setListings(listingsData || []);
      setTransactions(transactionsData || []);
    } catch (error) {
      console.error('Error loading dashboard data:', error);
    } finally {
      setIsLoadingData(false);
    }
  };

  if (!user) return null;

  const stats = [
    {
      title: 'Saldo X$',
      value: `${user.balance_xs.toFixed(2)} X$`,
      description: 'Moeda virtual disponível',
      icon: <Wallet className="w-6 h-6 text-primary-500" />,
      color: 'from-primary-500 to-primary-600'
    },
    {
      title: 'Bónus €',
      value: `€${user.balance_bonus.toFixed(2)}`,
      description: 'Crédito para comissões',
      icon: <Gift className="w-6 h-6 text-secondary-500" />,
      color: 'from-secondary-500 to-secondary-600'
    },
    {
      title: 'Dívida',
      value: user.debt_xs > 0 ? `${user.debt_xs.toFixed(2)} X$` : 'Sem dívida',
      description: 'Empréstimo pendente',
      icon: <CreditCard className="w-6 h-6 text-red-500" />,
      color: user.debt_xs > 0 ? 'from-red-500 to-red-600' : 'from-green-500 to-green-600'
    }
  ];

  const quickActions = [
    {
      title: 'Criar Anúncio',
      description: 'Publique um novo produto ou serviço',
      icon: <ShoppingBag className="w-6 h-6" />,
      href: '/create-listing',
      color: 'bg-gradient-to-r from-blue-500 to-blue-600'
    },
    {
      title: 'Ver Marketplace',
      description: 'Explore produtos e serviços disponíveis',
      icon: <Users className="w-6 h-6" />,
      href: '/marketplace',
      color: 'bg-gradient-to-r from-green-500 to-green-600'
    },
    {
      title: 'Solicitar Crédito',
      description: 'Peça um empréstimo em X$',
      icon: <TrendingUp className="w-6 h-6" />,
      href: '/request-loan',
      color: 'bg-gradient-to-r from-purple-500 to-purple-600'
    }
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-orange-50 py-8">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">
            Olá, {user.name}! 👋
          </h1>
          <p className="text-gray-600">
            Bem-vindo ao seu dashboard da XPermutas
          </p>
          
          {user.status === 'pending' && (
            <motion.div
              initial={{ opacity: 0, y: -10 }}
              animate={{ opacity: 1, y: 0 }}
              className="mt-4 bg-yellow-50 border border-yellow-200 text-yellow-800 px-4 py-3 rounded-lg flex items-center space-x-2"
            >
              <AlertCircle className="w-5 h-5 flex-shrink-0" />
              <span>A sua conta está pendente de aprovação. Será contactado em breve.</span>
            </motion.div>
          )}
        </div>

        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          {stats.map((stat, index) => (
            <motion.div
              key={index}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: index * 0.1 }}
            >
              <GlassCard hover className="p-6 bg-white/60">
                <div className="flex items-center justify-between mb-4">
                  <div className={`p-3 rounded-lg bg-gradient-to-r ${stat.color}`}>
                    <div className="text-white">
                      {stat.icon}
                    </div>
                  </div>
                </div>
                <h3 className="text-lg font-semibold text-gray-900 mb-1">
                  {stat.title}
                </h3>
                <p className="text-2xl font-bold text-gray-900 mb-2">
                  {stat.value}
                </p>
                <p className="text-sm text-gray-600">
                  {stat.description}
                </p>
              </GlassCard>
            </motion.div>
          ))}
        </div>

        {/* Quick Actions */}
        <div className="mb-8">
          <h2 className="text-2xl font-bold text-gray-900 mb-6">Ações Rápidas</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {quickActions.map((action, index) => (
              <motion.div
                key={index}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.6, delay: index * 0.1 + 0.3 }}
              >
                <Link to={action.href}>
                  <GlassCard hover className="p-6 bg-white/60 cursor-pointer">
                    <div className={`w-12 h-12 ${action.color} rounded-lg flex items-center justify-center mb-4 text-white`}>
                      {action.icon}
                    </div>
                    <h3 className="text-lg font-semibold text-gray-900 mb-2">
                      {action.title}
                    </h3>
                    <p className="text-gray-600">
                      {action.description}
                    </p>
                  </GlassCard>
                </Link>
              </motion.div>
            ))}
          </div>
        </div>

        {/* Referral Section */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.6 }}
          className="mb-8"
        >
          <GlassCard className="p-6 bg-gradient-to-r from-primary-500/10 to-secondary-500/10">
            <div className="flex flex-col md:flex-row items-center justify-between">
              <div className="mb-4 md:mb-0">
                <h3 className="text-xl font-bold text-gray-900 mb-2">
                  Programa de Indicação
                </h3>
                <p className="text-gray-600 mb-2">
                  Convide amigos e ganhe bónus em cada registo aprovado
                </p>
                <p className="text-sm text-gray-500">
                  Seu código: <span className="font-mono font-bold text-primary-600">{user.referral_code}</span>
                </p>
              </div>
              <Link
                to="/referrals"
                className="bg-primary-600 text-white px-6 py-3 rounded-lg hover:bg-primary-700 transition-colors"
              >
                Ver Detalhes
              </Link>
            </div>
          </GlassCard>
        </motion.div>

        {/* Recent Activity */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Recent Listings */}
          <div>
            <h2 className="text-2xl font-bold text-gray-900 mb-6">Meus Anúncios Recentes</h2>
            <GlassCard className="p-6 bg-white/60">
              {isLoadingData ? (
                <div className="text-center py-8">
                  <div className="w-8 h-8 border-2 border-primary-500 border-t-transparent rounded-full animate-spin mx-auto mb-2"></div>
                  <p className="text-gray-600">A carregar...</p>
                </div>
              ) : listings.length > 0 ? (
                <div className="space-y-4">
                  {listings.map((listing) => (
                    <div key={listing.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                      <div>
                        <h4 className="font-medium text-gray-900">{listing.title}</h4>
                        <p className="text-sm text-gray-600">{listing.price.toFixed(2)} X$</p>
                      </div>
                      <span className={`px-2 py-1 text-xs rounded-full ${
                        listing.status === 'active' ? 'bg-green-100 text-green-800' :
                        listing.status === 'sold' ? 'bg-blue-100 text-blue-800' :
                        'bg-gray-100 text-gray-800'
                      }`}>
                        {listing.status === 'active' ? 'Ativo' :
                         listing.status === 'sold' ? 'Vendido' : 'Inativo'}
                      </span>
                    </div>
                  ))}
                  <Link
                    to="/my-listings"
                    className="block text-center text-primary-600 hover:text-primary-700 font-medium"
                  >
                    Ver todos os anúncios
                  </Link>
                </div>
              ) : (
                <div className="text-center py-8">
                  <ShoppingBag className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                  <h3 className="text-lg font-medium text-gray-900 mb-2">
                    Nenhum anúncio ainda
                  </h3>
                  <p className="text-gray-600 mb-4">
                    Comece criando o seu primeiro anúncio
                  </p>
                  <Link
                    to="/create-listing"
                    className="bg-primary-600 text-white px-6 py-2 rounded-lg hover:bg-primary-700 transition-colors"
                  >
                    Criar Anúncio
                  </Link>
                </div>
              )}
            </GlassCard>
          </div>

          {/* Recent Transactions */}
          <div>
            <h2 className="text-2xl font-bold text-gray-900 mb-6">Transações Recentes</h2>
            <GlassCard className="p-6 bg-white/60">
              {isLoadingData ? (
                <div className="text-center py-8">
                  <div className="w-8 h-8 border-2 border-primary-500 border-t-transparent rounded-full animate-spin mx-auto mb-2"></div>
                  <p className="text-gray-600">A carregar...</p>
                </div>
              ) : transactions.length > 0 ? (
                <div className="space-y-4">
                  {transactions.map((transaction) => (
                    <div key={transaction.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                      <div>
                        <h4 className="font-medium text-gray-900">
                          {transaction.buyer_id === user.id ? 'Compra' : 'Venda'}
                        </h4>
                        <p className="text-sm text-gray-600">{transaction.amount.toFixed(2)} X$</p>
                      </div>
                      <span className={`px-2 py-1 text-xs rounded-full ${
                        transaction.status === 'completed' ? 'bg-green-100 text-green-800' :
                        transaction.status === 'pending' ? 'bg-yellow-100 text-yellow-800' :
                        'bg-red-100 text-red-800'
                      }`}>
                        {transaction.status === 'completed' ? 'Concluída' :
                         transaction.status === 'pending' ? 'Pendente' : 'Cancelada'}
                      </span>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-8">
                  <TrendingUp className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                  <h3 className="text-lg font-medium text-gray-900 mb-2">
                    Nenhuma transação ainda
                  </h3>
                  <p className="text-gray-600 mb-4">
                    Explore o marketplace para começar a negociar
                  </p>
                  <Link
                    to="/marketplace"
                    className="bg-primary-600 text-white px-6 py-2 rounded-lg hover:bg-primary-700 transition-colors"
                  >
                    Explorar Marketplace
                  </Link>
                </div>
              )}
            </GlassCard>
          </div>
        </div>
      </div>
    </div>
  );
}
