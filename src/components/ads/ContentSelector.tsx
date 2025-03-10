import React from 'react';
import type { Content } from '../../types/ads';

interface ContentSelectorProps {
  content: Content[];
  selectedContent: Content | null;
  onSelectContent: (content: Content) => void;
}

export function ContentSelector({ content, selectedContent, onSelectContent }: ContentSelectorProps) {
  return (
    <div>
      <div className="flex items-center space-x-2 mb-6">
        <div className="flex-1 h-px bg-gradient-to-r from-transparent via-cyan-400/50 to-transparent" />
        <h3 className="text-sm font-medium text-cyan-400">Select Content to Promote</h3>
        <div className="flex-1 h-px bg-gradient-to-r from-transparent via-cyan-400/50 to-transparent" />
      </div>
      <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
        {content.map((item) => (
          <button
            key={item.id}
            onClick={() => onSelectContent(item)}
            className="aspect-square bg-gray-800 rounded-lg overflow-hidden hover:ring-2 hover:ring-cyan-400 transition-all relative group"
          >
            {item.type === 'vibe' ? (
              <img
                src={item.content_url}
                alt={item.caption}
                className="w-full h-full object-cover"
              />
            ) : (
              <video
                src={item.content_url}
                className="w-full h-full object-cover"
              />
            )}
            <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity flex items-end p-3">
              <span className="text-sm text-white font-medium truncate">{item.caption}</span>
            </div>
          </button>
        ))}
      </div>
    </div>
  );
}