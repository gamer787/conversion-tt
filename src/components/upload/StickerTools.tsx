import React from 'react';
import { Sticker, Search } from 'lucide-react';

interface StickerToolsProps {
  selectedStickers: Array<{
    id: string;
    url: string;
    position: { x: number; y: number };
    scale: number;
    rotation: number;
  }>;
  onStickerAdd: (sticker: {
    id: string;
    url: string;
    position: { x: number; y: number };
    scale: number;
    rotation: number;
  }) => void;
  onStickerRemove: (id: string) => void;
}

// Example sticker categories and stickers
const STICKERS = {
  Emojis: [
    '😊', '😂', '🥰', '😎', '🤔', '🔥', '💯', '✨'
  ],
  Shapes: [
    '❤️', '⭐', '🌟', '💫', '💥', '💭', '💬', '🔷'
  ],
  Animals: [
    '🐶', '🐱', '🦊', '🦁', '🐼', '🐨', '🐯', '🦄'
  ],
  Food: [
    '🍕', '🍔', '🍟', '🌭', '🍿', '🍩', '🍪', '🍫'
  ]
};

export function StickerTools({
  selectedStickers,
  onStickerAdd,
  onStickerRemove
}: StickerToolsProps) {
  const [searchQuery, setSearchQuery] = React.useState('');
  const [selectedCategory, setSelectedCategory] = React.useState('Emojis');

  const handleStickerSelect = (emoji: string) => {
    onStickerAdd({
      id: Math.random().toString(),
      url: emoji,
      position: { x: 50, y: 50 },
      scale: 1,
      rotation: 0
    });
  };

  return (
    <div className="p-4 space-y-4">
      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-5 h-5" />
        <input
          type="text"
          placeholder="Search stickers..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="w-full bg-gray-800 border border-gray-700 rounded-lg pl-10 pr-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
        />
      </div>

      <div className="flex space-x-2 overflow-x-auto pb-2">
        {Object.keys(STICKERS).map((category) => (
          <button
            key={category}
            onClick={() => setSelectedCategory(category)}
            className={`px-4 py-1 rounded-full whitespace-nowrap ${
              selectedCategory === category
                ? 'bg-cyan-400 text-gray-900'
                : 'bg-gray-800 text-gray-400 hover:bg-gray-700'
            }`}
          >
            {category}
          </button>
        ))}
      </div>

      <div className="grid grid-cols-4 gap-4">
        {STICKERS[selectedCategory as keyof typeof STICKERS]
          .filter(sticker => 
            searchQuery ? sticker.toLowerCase().includes(searchQuery.toLowerCase()) : true
          )
          .map((sticker) => (
            <button
              key={sticker}
              onClick={() => handleStickerSelect(sticker)}
              className="aspect-square bg-gray-800 rounded-lg flex items-center justify-center text-2xl hover:bg-gray-700 transition-colors"
            >
              {sticker}
            </button>
          ))}
      </div>

      {selectedStickers.length > 0 && (
        <div>
          <h3 className="text-sm font-medium text-gray-400 mb-2">Added Stickers</h3>
          <div className="flex flex-wrap gap-2">
            {selectedStickers.map((sticker) => (
              <div
                key={sticker.id}
                className="bg-gray-800 p-2 rounded-lg flex items-center space-x-2"
              >
                <span className="text-xl">{sticker.url}</span>
                <button
                  onClick={() => onStickerRemove(sticker.id)}
                  className="text-red-400 hover:text-red-300 text-sm"
                >
                  Remove
                </button>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}