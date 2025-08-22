import React, { useState, useEffect, useCallback } from 'react';
import { supabase, DatabaseListing } from '../../../lib/supabase';
import { Loader2, Search, Trash2, Edit } from 'lucide-react';
import { Badge } from '../../../components/ui/Badge';

export function AdminListings() {
  const [listings, setListings] = useState<DatabaseListing[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');

  const fetchListings = useCallback(async () => {
    setIsLoading(true);
    let query = supabase
      .from('listings')
      .select('*, users(name)')
      .order('created_at', { ascending: false });

    if (searchTerm) {
      query = query.or(`title.ilike.%${searchTerm}%`);
    }

    const { data, error } = await query;
    if (error) console.error('Error fetching listings:', error);
    else setListings(data || []);
    setIsLoading(false);
  }, [searchTerm]);

  useEffect(() => {
    fetchListings();
  }, [fetchListings]);
  
  const handleDelete = async (listingId: string) => {
    if (window.confirm('Tem a certeza que quer apagar este anúncio? Esta ação é irreversível.')) {
      const { error } = await supabase.from('listings').delete().eq('id', listingId);
      if (error) {
        alert('Erro ao apagar anúncio: ' + error.message);
      } else {
        fetchListings();
      }
    }
  };

  return (
    <div>
      <h1 className="text-2xl font-bold text-gray-800 mb-6">Gestão de Anúncios</h1>
      <div className="mb-4 relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
        <input
          type="text"
          placeholder="Procurar por título..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="w-full max-w-sm pl-10 pr-4 py-2 border border-gray-300 rounded-lg"
        />
      </div>
      <div className="bg-white shadow-md rounded-lg overflow-x-auto">
        <table className="w-full table-auto">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Título</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Vendedor</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Preço</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Ações</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {isLoading ? (
              <tr><td colSpan={5} className="text-center py-8"><Loader2 className="w-8 h-8 text-primary-500 animate-spin mx-auto" /></td></tr>
            ) : (
              listings.map(listing => (
                <tr key={listing.id}>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{listing.title}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{listing.users?.name || 'N/A'}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{listing.price.toFixed(2)} X$</td>
                  <td className="px-6 py-4 whitespace-nowrap"><Badge color={listing.status === 'active' ? 'green' : 'gray'}>{listing.status}</Badge></td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium space-x-4">
                    <button onClick={() => alert('Função de editar em desenvolvimento')} className="text-primary-600 hover:text-primary-900"><Edit className="w-5 h-5" /></button>
                    <button onClick={() => handleDelete(listing.id)} className="text-red-600 hover:text-red-900"><Trash2 className="w-5 h-5" /></button>
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
