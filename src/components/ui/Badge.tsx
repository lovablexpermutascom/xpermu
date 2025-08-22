import React from 'react';
import { clsx } from 'clsx';

interface BadgeProps {
  color?: 'green' | 'yellow' | 'red' | 'blue' | 'gray';
  children: React.ReactNode;
  className?: string;
}

export function Badge({ color = 'gray', children, className }: BadgeProps) {
  const colorClasses = {
    green: 'bg-green-100 text-green-800',
    yellow: 'bg-yellow-100 text-yellow-800',
    red: 'bg-red-100 text-red-800',
    blue: 'bg-blue-100 text-blue-800',
    gray: 'bg-gray-100 text-gray-800',
  };

  return (
    <span
      className={clsx(
        'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium',
        colorClasses[color],
        className
      )}
    >
      {children}
    </span>
  );
}
