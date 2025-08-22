import React from 'react';
import { AdminSidebar } from './AdminSidebar';
import { Link } from 'react-router-dom';

export function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex h-screen bg-gray-100">
      <AdminSidebar />
      <div className="flex-1 flex flex-col overflow-hidden">
        <header className="flex justify-between items-center p-4 bg-white border-b">
          <h1 className="text-xl font-semibold">Painel de Administração</h1>
          <Link to="/" className="text-sm text-primary-600 hover:underline">
            Voltar ao Site
          </Link>
        </header>
        <main className="flex-1 overflow-x-hidden overflow-y-auto bg-gray-100 p-6">
          {children}
        </main>
      </div>
    </div>
  );
}
