import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { Navbar } from './components/Layout/Navbar';
import { Footer } from './components/Layout/Footer';
import { Home } from './pages/Home';
import { Login } from './pages/Login';
import { Register } from './pages/Register';
import { Dashboard } from './pages/Dashboard';
import { Marketplace } from './pages/Marketplace';
import { ListingDetail } from './pages/ListingDetail';
import { CreateListing } from './pages/CreateListing';
import { Referrals } from './pages/Referrals';

// Admin Imports
import { AdminRoute } from './components/admin/AdminRoute';
import { AdminLayout } from './components/admin/AdminLayout';
import { AdminDashboard } from './pages/admin/AdminDashboard';
import { AdminUsers } from './pages/admin/users/AdminUsers';
import { AdminListings } from './pages/admin/listings/AdminListings';
import { AdminTransactions } from './pages/admin/transactions/AdminTransactions';
import { AdminCategories } from './pages/admin/categories/AdminCategories';
import { AdminSettings } from './pages/admin/settings/AdminSettings';


function App() {
  return (
    <AuthProvider>
      <Router>
        <div className="min-h-screen flex flex-col">
          <Routes>
            {/* Admin Routes */}
            <Route path="/admin/*" element={
              <AdminRoute>
                <AdminLayout>
                  <Routes>
                    <Route path="/" element={<AdminDashboard />} />
                    <Route path="/users" element={<AdminUsers />} />
                    <Route path="/listings" element={<AdminListings />} />
                    <Route path="/transactions" element={<AdminTransactions />} />
                    <Route path="/categories" element={<AdminCategories />} />
                    <Route path="/settings" element={<AdminSettings />} />
                  </Routes>
                </AdminLayout>
              </AdminRoute>
            } />

            {/* Public Routes */}
            <Route path="/*" element={<MainApp />} />
          </Routes>
        </div>
      </Router>
    </AuthProvider>
  );
}

// Main App component with Navbar and Footer
const MainApp = () => (
  <>
    <Navbar />
    <main className="flex-1">
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/login" element={<Login />} />
        <Route path="/register" element={<Register />} />
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/marketplace" element={<Marketplace />} />
        <Route path="/listings/:id" element={<ListingDetail />} />
        <Route path="/create-listing" element={<CreateListing />} />
        <Route path="/referrals" element={<Referrals />} />
        <Route path="/my-listings" element={<div className="min-h-screen flex items-center justify-center"><p className="text-xl">Meus Anúncios em desenvolvimento</p></div>} />
        <Route path="/profile" element={<div className="min-h-screen flex items-center justify-center"><p className="text-xl">Perfil em desenvolvimento</p></div>} />
        <Route path="/request-loan" element={<div className="min-h-screen flex items-center justify-center"><p className="text-xl">Solicitar Crédito em desenvolvimento</p></div>} />
      </Routes>
    </main>
    <Footer />
  </>
);

export default App;
