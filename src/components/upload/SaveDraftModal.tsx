import React from 'react';

interface SaveDraftModalProps {
  onSave: () => void;
  onDiscard: () => void;
}

export function SaveDraftModal({ onSave, onDiscard }: SaveDraftModalProps) {
  return (
    <div className="fixed inset-0 bg-black/75 flex items-center justify-center z-50 p-4">
      <div className="bg-gray-900 rounded-lg p-6 max-w-sm w-full">
        <h3 className="text-lg font-semibold mb-4">Save as Draft?</h3>
        <p className="text-gray-400 mb-6">
          You can continue editing this post later from your drafts.
        </p>
        <div className="flex space-x-4">
          <button
            onClick={onDiscard}
            className="flex-1 bg-red-500 text-white py-2 rounded-lg font-medium hover:bg-red-600 transition-colors"
          >
            Discard
          </button>
          <button
            onClick={onSave}
            className="flex-1 bg-cyan-400 text-gray-900 py-2 rounded-lg font-medium hover:bg-cyan-300 transition-colors"
          >
            Save Draft
          </button>
        </div>
      </div>
    </div>
  );
}