import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { supabase, DatabaseListing } from '../lib/supabase';
import { Loader2, ArrowLeft, User, MapPin, Tag, Phone, MessageSquare, ShoppingCart } from 'lucide-react';
import { motion } from 'framer-motion';

export function ListingDetail() {
  const { id } = useParams<{ id: string }>();
  const [listing, setListing] = useState<DatabaseListing | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (id) {
      fetchListing();
    }
  }, [id]);

  const fetchListing = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const { data, error } = await supabase
        .from('listings')
        .select(`
          *,
          users (*),
          categories (*)
        `)
        .eq('id', id)
        .eq('status', 'active')
        .single();

      if (error) throw error;
      setListing(data);
    } catch (err) {
      console.error('Error fetching listing:', err);
      setError('Anúncio não encontrado ou indisponível.');
    } finally {
      setIsLoading(false);
    }
  };

  if (isLoading) {
    return (
      <div className="min-h-screen flex justify-center items-center">
        <Loader2 className="w-12 h-12 text-primary-500 animate-spin" />
      </div>
    );
  }

  if (error || !listing) {
    return (
      <div className="min-h-screen flex flex-col justify-center items-center text-center px-4">
        <h2 className="text-2xl font-bold text-gray-800 mb-4">{error || 'Anúncio não encontrado'}</h2>
        <Link
          to="/marketplace"
          className="bg-primary-600 text-white px-6 py-2 rounded-lg hover:bg-primary-700 transition-colors flex items-center space-x-2"
        >
          <ArrowLeft className="w-5 h-5" />
          <span>Voltar ao Marketplace</span>
        </Link>
      </div>
    );
  }

  const whatsappLink = `https://wa.me/${listing.users?.whatsapp.replace('+', '')}?text=${encodeURIComponent(`Olá, tenho interesse no seu anúncio "${listing.title}" na XPermutas.com.`)}`;

  return (
    <div className="min-h-screen bg-gray-50 py-12">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          <div className="mb-6">
            <Link to="/marketplace" className="text-primary-600 hover:underline flex items-center space-x-2">
              <ArrowLeft className="w-4 h-4" />
              <span>Voltar ao Marketplace</span>
            </Link>
          </div>

          <div className="bg-white shadow-xl rounded-2xl overflow-hidden md:grid md:grid-cols-2">
            {/* Image Gallery */}
            <div className="p-4">
              <img 
                src={listing.images && listing.images.length > 0 ? listing.images[0] : `https://img-wrapper.vercel.app/image?url=https://placehold.co/800x600/${listing.categories?.color?.substring(1) || '0066cc'}/ffffff?text=${encodeURIComponent(listing.title)}`}
                alt={listing.title}
                className="w-full h-auto object-cover rounded-lg"
              />
            </div>

            {/* Listing Info */}
            <div className="p-8 flex flex-col">
              {listing.categories && (
                <div className="flex items-center text-sm text-gray-600 mb-2">
                  <Tag className="w-4 h-4 mr-2" style={{ color: listing.categories.color || '#6b7280' }} />
                  <span>{listing.categories.name}</span>
                </div>
              )}
              <h1 className="text-3xl md:text-4xl font-bold text-gray-900 mb-4">{listing.title}</h1>
              <p className="text-3xl font-bold text-primary-600 mb-6">
                {listing.price.toFixed(2)} X$
              </p>
              
              <div className="prose max-w-none text-gray-700 mb-8">
                <p>{listing.description}</p>
              </div>

              {/* Seller Info */}
              <div className="mt-auto pt-6 border-t border-gray-200">
                <h3 className="text-lg font-semibold text-gray-800 mb-4">Informações do Vendedor</h3>
                <div className="flex items-center space-x-4 mb-4">
                  <div className="flex items-center text-gray-700">
                    <User className="w-5 h-5 mr-2 text-primary-500" />
                    <span>{listing.users?.name}</span>
                  </div>
                  {listing.location && (
                    <div className="flex items-center text-gray-700">
                      <MapPin className="w-5 h-5 mr-2 text-primary-500" />
                      <span>{listing.location}</span>
                    </div>
                  )}
                </div>
                
                {/* Action Buttons */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <a
                    href={whatsappLink}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="w-full bg-green-500 text-white px-6 py-3 rounded-lg hover:bg-green-600 transition-colors flex items-center justify-center space-x-2 font-semibold"
                  >
                    <MessageSquare className="w-5 h-5" />
                    <span>Contactar Vendedor</span>
                  </a>
                  <button
                    className="w-full bg-primary-600 text-white px-6 py-3 rounded-lg hover:bg-primary-700 transition-colors flex items-center justify-center space-x-2 font-semibold"
                  >
                    <ShoppingCart className="w-5 h-5" />
                    <span>Iniciar Compra</span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  );
}
