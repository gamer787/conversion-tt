import React from 'react';
import type { PriceTier } from '../../types/ads';

interface PricingTiersProps {
  priceTiers: PriceTier[];
  selectedTier: PriceTier | null;
  onSelectTier: (tier: PriceTier) => void;
}

export function PricingTiers({ priceTiers, selectedTier, onSelectTier }: PricingTiersProps) {
  return (
    <div className="bg-gray-800/50 p-4 rounded-lg border border-gray-700/50">
      <label className="block text-sm font-medium text-cyan-400 mb-4">
        Campaign Package
      </label>
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        {priceTiers.map((tier) => (
          <button
            key={tier.id}
            onClick={() => onSelectTier(tier)}
            className={`p-4 rounded-lg border transition-colors ${
              selectedTier?.id === tier.id
                ? 'border-cyan-400 bg-cyan-400/10'
                : 'border-gray-700 hover:border-gray-600'
            }`}
          >
            <div className="text-lg font-bold mb-1">₹{tier.price}</div>
            <div className="text-sm text-gray-400">
              {tier.duration_hours}h • {tier.radius_km}km
            </div>
            <div className="text-xs text-gray-500 mt-1">
              {tier.radius_km >= 100 ? 'Regional' : 'Local'} Reach
            </div>
          </button>
        ))}
      </div>
    </div>
  );
}