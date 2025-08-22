import React, { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { supabase, DatabaseUser } from '../lib/supabase';
import { Gift, Link as LinkIcon, Copy, Users, Loader2 } from 'lucide-react';
import { motion } from 'framer-motion';
import { GlassCard } from '../components/ui/GlassCard';
import { Badge } from '../components/ui/Badge';

export function Referrals() {
  const { user } = useAuth();
  const [referredUsers, setReferredUsers] = useState<DatabaseUser[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (user) {
      fetchReferredUsers();
    }
  }, [user]);

  const fetchReferredUsers = async () => {
    if (!user) return;
    setIsLoading(true);
    try {
      const { data, error } = await supabase
        .from('users')
        .select('*')
        .eq('referred_by', user.id)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setReferredUsers(data || []);
    } catch (error) {
      console.error('Error fetching referred users:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleCopy = (text: string) => {
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  if (!user) {
    return (
      <div className="min-h-screen flex justify-center items-center">
        <Loader2 className="w-12 h-12 text-primary-500 animate-spin" />
      </div>
    );
  }

  const referralLink = `${window.location.origin}/register?ref=${user.referral_code}`;
  
  const getStatusColor = (status: DatabaseUser['status']) => {
    switch (status) {
      case 'approved': return 'green';
      case 'pending': return 'yellow';
      case 'rejected': return 'red';
      case 'suspended': return 'gray';
      default: return 'gray';
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-orange-50 py-12">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          <div className="text-center mb-12">
            <Gift className="w-16 h-16 text-primary-500 mx-auto mb-4" />
            <h1 className="text-4xl font-bold text-gray-900 mb-2">Programa de Indicação</h1>
            <p className="text-lg text-gray-600">Convide amigos e ganhe bónus por cada registo aprovado!</p>
          </div>

          <GlassCard className="p-8 mb-12 bg-white/60">
            <h2 className="text-2xl font-bold text-gray-800 mb-4">O seu Link de Partilha</h2>
            <p className="text-gray-600 mb-2">Partilhe o seu código ou link com a sua rede.</p>
            
            <div className="mb-4">
              <label className="block text-sm font-medium text-gray-700">O seu Código</label>
              <div className="mt-1 flex rounded-md shadow-sm">
                <input
                  type="text"
                  readOnly
                  value={user.referral_code}
                  className="flex-1 block w-full rounded-none rounded-l-md sm:text-sm border-gray-300 bg-gray-100 p-3"
                />
                <button
                  onClick={() => handleCopy(user.referral_code)}
                  className="relative inline-flex items-center space-x-2 px-4 py-2 border border-gray-300 text-sm font-medium rounded-r-md text-gray-700 bg-gray-50 hover:bg-gray-100"
                >
                  <Copy className="h-5 w-5" />
                  <span>{copied ? 'Copiado!' : 'Copiar'}</span>
                </button>
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">O seu Link</label>
              <div className="mt-1 flex rounded-md shadow-sm">
                <input
                  type="text"
                  readOnly
                  value={referralLink}
                  className="flex-1 block w-full rounded-none rounded-l-md sm:text-sm border-gray-300 bg-gray-100 p-3"
                />
                <button
                  onClick={() => handleCopy(referralLink)}
                  className="relative inline-flex items-center space-x-2 px-4 py-2 border border-gray-300 text-sm font-medium rounded-r-md text-gray-700 bg-gray-50 hover:bg-gray-100"
                >
                  <LinkIcon className="h-5 w-5" />
                  <span>{copied ? 'Copiado!' : 'Copiar'}</span>
                </button>
              </div>
            </div>
          </GlassCard>

          <div>
            <h2 className="text-2xl font-bold text-gray-800 mb-6">Minhas Indicações</h2>
            <GlassCard className="p-6 bg-white/60">
              {isLoading ? (
                <div className="text-center py-8">
                  <Loader2 className="w-8 h-8 text-primary-500 animate-spin mx-auto" />
                </div>
              ) : referredUsers.length > 0 ? (
                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y divide-gray-200">
                    <thead className="bg-gray-50/50">
                      <tr>
                        <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Nome</th>
                        <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Data de Registo</th>
                        <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                      </tr>
                    </thead>
                    <tbody className="bg-white/50 divide-y divide-gray-200">
                      {referredUsers.map((refUser) => (
                        <tr key={refUser.id}>
                          <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{refUser.name}</td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{new Date(refUser.created_at).toLocaleDateString()}</td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            <Badge color={getStatusColor(refUser.status)}>{refUser.status}</Badge>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ) : (
                <div className="text-center py-12">
                  <Users className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                  <h3 className="text-lg font-medium text-gray-900 mb-2">Nenhuma indicação ainda</h3>
                  <p className="text-gray-600">Partilhe o seu código para começar a ganhar bónus!</p>
                </div>
              )}
            </GlassCard>
          </div>
        </motion.div>
      </div>
    </div>
  );
}
