import React from 'react';
import { Trash2, X } from 'lucide-react';

interface DeletePostModalProps {
  onConfirm: () => void;
  onCancel: () => void;
  type: 'vibe' | 'banger';
}

export function DeletePostModal({ onConfirm, onCancel, type }: DeletePostModalProps) {
  return (
    <div className="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-[100] p-4">
      <div className="bg-gray-900 rounded-lg w-full max-w-md p-6">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center space-x-2 text-red-500">
            <Trash2 className="w-6 h-6" />
            <h2 className="text-xl font-bold">Delete {type === 'vibe' ? 'Vibe' : 'Banger'}</h2>
          </div>
          <button 
            onClick={onCancel}
            className="text-gray-400 hover:text-white transition-colors"
          >
            <X className="w-6 h-6" />
          </button>
        </div>
        
        <p className="text-gray-300 mb-6">
          Are you sure you want to delete this {type}? This action cannot be undone.
        </p>

        <div className="flex space-x-4">
          <button
            onClick={onCancel}
            className="flex-1 py-2 px-4 bg-gray-800 text-white rounded-lg hover:bg-gray-700 transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            className="flex-1 py-2 px-4 bg-red-500 text-white rounded-lg hover:bg-red-600 transition-colors"
          >
            Delete
          </button>
        </div>
      </div>
    </div>
  );
}