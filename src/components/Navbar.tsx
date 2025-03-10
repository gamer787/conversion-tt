import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { Home, Search, PlusSquare, User, Building2, Film } from 'lucide-react';

export function Navbar() {
  const navigate = useNavigate();

  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-gray-900 border-t border-gray-800 z-50">
      <div className="max-w-lg mx-auto px-2">
        <div className="grid grid-cols-6 items-center py-3">
          <NavLink to="/" className={({ isActive }) => 
            `flex flex-col items-center ${isActive ? 'text-cyan-400' : 'text-gray-400'}`
          }>
            <Home size={22} />
            <span className="text-[10px] mt-0.5">Home</span>
          </NavLink>
          
          <NavLink to="/find" className={({ isActive }) => 
            `flex flex-col items-center ${isActive ? 'text-cyan-400' : 'text-gray-400'}`
          }>
            <Search size={22} />
            <span className="text-[10px] mt-0.5">Find</span>
          </NavLink>
          
          <button
            onClick={() => navigate('/?view=bangers')}
            className="flex flex-col items-center text-gray-400 hover:text-cyan-400"
          >
            <Film size={22} />
            <span className="text-[10px] mt-0.5">Bangers</span>
          </button>
          
          <NavLink to="/upload" className={({ isActive }) => 
            `flex flex-col items-center ${isActive ? 'text-cyan-400' : 'text-gray-400'}`
          }>
            <PlusSquare size={22} />
            <span className="text-[10px] mt-0.5">Create</span>
          </NavLink>

          <NavLink to="/profile" className={({ isActive }) => 
            `flex flex-col items-center ${isActive ? 'text-cyan-400' : 'text-gray-400'}`
          }>
            <User size={22} />
            <span className="text-[10px] mt-0.5">Profile</span>
          </NavLink>
          
          <NavLink to="/hub" className={({ isActive }) => 
            `flex flex-col items-center ${isActive ? 'text-cyan-400' : 'text-gray-400'}`
          }>
            <Building2 size={22} />
            <span className="text-[10px] mt-0.5">Hub</span>
          </NavLink>
        </div>
      </div>
    </nav>
  );
}