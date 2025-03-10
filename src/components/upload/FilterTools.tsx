import React from 'react';
import { Sparkles } from 'lucide-react';

interface FilterToolsProps {
  selectedFilter: string;
  onFilterSelect: (filter: string) => void;
}

const FILTERS = [
  { id: 'none', name: 'Normal' },
  { id: 'grayscale', name: 'B&W' },
  { id: 'sepia', name: 'Sepia' },
  { id: 'vintage', name: 'Vintage' },
  { id: 'fade', name: 'Fade' },
  { id: 'vivid', name: 'Vivid' },
  { id: 'cool', name: 'Cool' },
  { id: 'warm', name: 'Warm' },
  { id: 'dramatic', name: 'Dramatic' },
  { id: 'matte', name: 'Matte' }
];

export function FilterTools({ selectedFilter, onFilterSelect }: FilterToolsProps) {
  return (
    <div className="p-4">
      <div className="grid grid-cols-5 gap-4">
        {FILTERS.map((filter) => (
          <button
            key={filter.id}
            onClick={() => onFilterSelect(filter.id)}
            className={`flex flex-col items-center space-y-2 ${
              selectedFilter === filter.id
                ? 'text-cyan-400'
                : 'text-gray-400 hover:text-gray-300'
            }`}
          >
            <div className="w-16 h-16 bg-gray-800 rounded-lg flex items-center justify-center">
              <Sparkles className="w-6 h-6" />
            </div>
            <span className="text-xs">{filter.name}</span>
          </button>
        ))}
      </div>
    </div>
  );
}