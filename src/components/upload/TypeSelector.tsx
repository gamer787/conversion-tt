import React from 'react';
import { ImageIcon, Film } from 'lucide-react';

interface TypeSelectorProps {
  selectedType: 'vibe' | 'banger' | null;
  onTypeSelect: (type: 'vibe' | 'banger') => void;
}

export function TypeSelector({ selectedType, onTypeSelect }: TypeSelectorProps) {
  return (
    <div className="grid grid-cols-2 gap-4">
      <button
        onClick={() => onTypeSelect('vibe')}
        className={`p-6 rounded-lg flex flex-col items-center justify-center space-y-2 transition-colors ${
          selectedType === 'vibe'
            ? 'bg-cyan-400 text-gray-900'
            : 'bg-gray-900 text-gray-400 hover:bg-gray-800'
        }`}
      >
        <ImageIcon className="w-8 h-8" />
        <span className="font-medium">Vibe</span>
        <span className="text-sm opacity-75">Share photos & carousels</span>
      </button>

      <button
        onClick={() => onTypeSelect('banger')}
        className={`p-6 rounded-lg flex flex-col items-center justify-center space-y-2 transition-colors ${
          selectedType === 'banger'
            ? 'bg-cyan-400 text-gray-900'
            : 'bg-gray-900 text-gray-400 hover:bg-gray-800'
        }`}
      >
        <Film className="w-8 h-8" />
        <span className="font-medium">Banger</span>
        <span className="text-sm opacity-75">Create vertical videos</span>
      </button>
    </div>
  );
}