import React from 'react';
import { ImageIcon, Film, Users, Building2 } from 'lucide-react';
import type { Profile } from '../../types/database';

interface ProfileStatsProps {
  profile: Profile;
  stats: {
    vibes_count: number;
    bangers_count: number;
    links_count: number;
    brands_count: number;
  };
  onShowLinks: () => void;
  onShowBrands: () => void;
}

export function ProfileStats({ profile, stats, onShowLinks, onShowBrands }: ProfileStatsProps) {
  const isBusiness = profile.account_type === 'business';

  return (
    <div className="grid grid-cols-4 gap-4 py-4 border-t border-b border-gray-800">
      <div className="text-center">
        <div className="text-xl font-bold text-white">{stats.vibes_count}</div>
        <div className="text-sm text-gray-400 flex items-center justify-center">
          <ImageIcon className="w-4 h-4 mr-1" />
          Vibes
        </div>
      </div>
      <div className="text-center">
        <div className="text-xl font-bold text-white">{stats.bangers_count}</div>
        <div className="text-sm text-gray-400 flex items-center justify-center">
          <Film className="w-4 h-4 mr-1" />
          Bangers
        </div>
      </div>
      <button
        onClick={onShowLinks}
        className="text-center hover:bg-gray-800 rounded-lg p-2 transition-colors"
      >
        <div className="text-xl font-bold text-white">{stats.links_count}</div>
        <div className="text-sm text-gray-400 flex items-center justify-center">
          <Users className="w-4 h-4 mr-1" />
          {isBusiness ? 'Trusts' : 'Links'}
        </div>
      </button>
      <button
        onClick={onShowBrands}
        className="text-center hover:bg-gray-800 rounded-lg p-2 transition-colors"
      >
        <div className="text-xl font-bold text-white">{stats.brands_count}</div>
        <div className="text-sm text-gray-400 flex items-center justify-center">
          <Building2 className="w-4 h-4 mr-1" />
          Brands
        </div>
      </button>
    </div>
  );
}