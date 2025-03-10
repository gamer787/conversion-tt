import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { Bell } from 'lucide-react';

export function TopNav() {
  const location = useLocation();
  const isHomePage = location.pathname === '/';

  if (!isHomePage) return null;

  return (
    <div className="fixed top-0 left-0 right-0 z-50 bg-gray-950/95 backdrop-blur-sm">
      <div className="max-w-lg mx-auto px-6 py-4 flex items-center justify-between">
        <h1 className="text-xl font-bold">ZappaLink</h1>
        <div className="flex items-center space-x-3">
          <Link 
            to="/notifications" 
            className="w-10 h-10 bg-gray-900 rounded-full flex items-center justify-center text-gray-400 hover:text-cyan-400 transition-colors"
          >
            <Bell className="w-6 h-6" />
          </Link>
        </div>
      </div>
    </div>
  );
}