import React from 'react';
import { TrendingUp, Users, Info } from 'lucide-react';

interface ReachEstimatorProps {
  estimatedReach: number;
  duration: number;
  radius: number;
  price: number;
}

export function ReachEstimator({ estimatedReach, duration, radius, price }: ReachEstimatorProps) {
  return (
    <div className="bg-gradient-to-br from-cyan-400/10 to-purple-400/10 p-6 rounded-lg border border-cyan-400/20">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center text-cyan-400">
          <TrendingUp className="w-5 h-5 mr-2" />
          <span className="font-semibold">Estimated Reach</span>
        </div>
        <div>
          <div className="flex items-center space-x-2">
            <Users className="w-5 h-5 text-cyan-400" />
            <span className="text-lg font-bold">
              {estimatedReach.toLocaleString()}+ users
            </span>
          </div>
          <div className="flex items-center text-xs text-gray-400 mt-1">
            <Info className="w-3 h-3 mr-1" />
            Total users in range
          </div>
        </div>
      </div>
      <div className="flex items-center justify-between">
        <span className="text-gray-400">Total Price</span>
        <div>
          <span className="text-3xl font-bold">
            ₹{price}
          </span>
          <div className="text-xs text-gray-400">
            {duration} hours • {radius}km reach
          </div>
        </div>
      </div>
    </div>
  );
}