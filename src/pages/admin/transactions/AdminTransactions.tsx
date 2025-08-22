import React, { useState, useEffect } from 'react';
import { supabase, DatabaseTransaction } from '../../../lib/supabase';
import { Loader2 } from 'lucide-react';
import { Badge } from '../../../components/ui/Badge';

export function AdminTransactions() {
  const [transactions, setTransactions] = useState<DatabaseTransaction[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const fetchTransactions = async () => {
      setIsLoading(true);
      const { data, error } = await supabase
        .from('transactions')
        .select('*, buyer:buyer_id(name), seller:seller_id(name), listings(title)')
        .order('created_at', { ascending: false });
      
      if (error) console.error('Error fetching transactions:', error);
      else setTransactions(data || []);
      setIsLoading(false);
    };
    fetchTransactions();
  }, []);

  return (
    <div>
      <h1 className="text-2xl font-bold text-gray-800 mb-6">Gestão de Transações</h1>
      <div className="bg-white shadow-md rounded-lg overflow-x-auto">
        <table className="w-full table-auto">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Anúncio</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Comprador</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Vendedor</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Valor</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {isLoading ? (
              <tr><td colSpan={5} className="text-center py-8"><Loader2 className="w-8 h-8 text-primary-500 animate-spin mx-auto" /></td></tr>
            ) : (
              transactions.map(tx => (
                <tr key={tx.id}>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{tx.listings?.title || 'N/A'}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{tx.buyer?.name}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{tx.seller?.name}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{tx.amount.toFixed(2)} X$</td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <Badge color={tx.status === 'completed' ? 'green' : tx.status === 'pending' ? 'yellow' : 'red'}>{tx.status}</Badge>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
