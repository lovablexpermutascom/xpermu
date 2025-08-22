import React from 'react';
import { Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import { GlassCard } from '../ui/GlassCard';
import { Tag, User, MapPin } from 'lucide-react';
import { DatabaseListing } from '../../lib/supabase';

interface ListingCardProps {
  listing: DatabaseListing;
}

export function ListingCard({ listing }: ListingCardProps) {
  const placeholderImage = `https://img-wrapper.vercel.app/image?url=https://placehold.co/600x400/${listing.categories?.color?.substring(1) || '0066cc'}/ffffff?text=${encodeURIComponent(listing.title)}`;
  const imageUrl = listing.images && listing.images.length > 0 ? listing.images[0] : placeholderImage;

  return (
    <motion.div
      whileHover={{ y: -5 }}
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5 }}
    >
      <Link to={`/listings/${listing.id}`}>
        <GlassCard className="overflow-hidden h-full flex flex-col bg-white/60">
          <div className="relative">
            <img 
              src={imageUrl} 
              alt={listing.title} 
              className="w-full h-48 object-cover" 
            />
            <div className="absolute top-2 right-2 bg-primary-500 text-white text-sm font-bold px-3 py-1 rounded-full shadow-lg">
              {listing.price.toFixed(2)} X$
            </div>
          </div>
          <div className="p-4 flex flex-col flex-grow">
            {listing.categories && (
              <div className="flex items-center text-sm text-gray-600 mb-2">
                <Tag className="w-4 h-4 mr-2" style={{ color: listing.categories.color || '#6b7280' }} />
                <span>{listing.categories.name}</span>
              </div>
            )}
            <h3 className="text-lg font-semibold text-gray-900 mb-2 flex-grow">
              {listing.title}
            </h3>
            <div className="border-t border-gray-200 pt-3 mt-auto">
              <div className="flex items-center text-sm text-gray-600">
                <User className="w-4 h-4 mr-2 text-primary-500" />
                <span>{listing.users?.name || 'Vendedor'}</span>
              </div>
              {listing.location && (
                <div className="flex items-center text-sm text-gray-600 mt-1">
                  <MapPin className="w-4 h-4 mr-2 text-primary-500" />
                  <span>{listing.location}</span>
                </div>
              )}
            </div>
          </div>
        </GlassCard>
      </Link>
    </motion.div>
  );
}
