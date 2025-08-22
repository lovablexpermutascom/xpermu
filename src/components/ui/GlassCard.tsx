import React from 'react';
import { motion } from 'framer-motion';
import { clsx } from 'clsx';

interface GlassCardProps {
  children: React.ReactNode;
  className?: string;
  hover?: boolean;
}

export function GlassCard({ children, className, hover = false }: GlassCardProps) {
  return (
    <motion.div
      whileHover={hover ? { y: -2 } : {}}
      className={clsx(
        'bg-white/20 backdrop-blur-md border border-white/30 rounded-xl shadow-lg',
        'backdrop-saturate-150',
        className
      )}
    >
      {children}
    </motion.div>
  );
}
