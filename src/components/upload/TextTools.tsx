import React, { useState } from 'react';
import { Type, Plus } from 'lucide-react';

interface TextOverlay {
  id: string;
  text: string;
  position: { x: number; y: number };
  style: {
    fontSize: number;
    color: string;
    fontFamily: string;
  };
}

interface TextToolsProps {
  textOverlays: TextOverlay[];
  onTextAdd: (text: TextOverlay) => void;
  onTextUpdate: (id: string, text: TextOverlay) => void;
  onTextRemove: (id: string) => void;
}

export function TextTools({
  textOverlays,
  onTextAdd,
  onTextUpdate,
  onTextRemove
}: TextToolsProps) {
  const [newText, setNewText] = useState('');
  const [selectedColor, setSelectedColor] = useState('#FFFFFF');
  const [fontSize, setFontSize] = useState(24);

  const handleAddText = () => {
    if (!newText.trim()) return;

    onTextAdd({
      id: Math.random().toString(),
      text: newText,
      position: { x: 50, y: 50 },
      style: {
        fontSize,
        color: selectedColor,
        fontFamily: 'sans-serif'
      }
    });

    setNewText('');
  };

  return (
    <div className="p-4 space-y-4">
      <div className="flex space-x-2">
        <input
          type="text"
          value={newText}
          onChange={(e) => setNewText(e.target.value)}
          placeholder="Add text..."
          className="flex-1 bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
        />
        <button
          onClick={handleAddText}
          disabled={!newText.trim()}
          className="p-2 bg-cyan-400 text-gray-900 rounded-lg hover:bg-cyan-300 transition-colors disabled:opacity-50"
        >
          <Plus className="w-5 h-5" />
        </button>
      </div>

      <div className="space-y-2">
        <label className="block text-sm font-medium text-gray-400">
          Font Size
        </label>
        <input
          type="range"
          min="12"
          max="72"
          value={fontSize}
          onChange={(e) => setFontSize(parseInt(e.target.value))}
          className="w-full"
        />
      </div>

      <div className="space-y-2">
        <label className="block text-sm font-medium text-gray-400">
          Color
        </label>
        <div className="flex space-x-2">
          {['#FFFFFF', '#FF0000', '#00FF00', '#0000FF', '#FFFF00', '#FF00FF', '#00FFFF'].map((color) => (
            <button
              key={color}
              onClick={() => setSelectedColor(color)}
              className={`w-8 h-8 rounded-full ${
                selectedColor === color ? 'ring-2 ring-cyan-400' : ''
              }`}
              style={{ backgroundColor: color }}
            />
          ))}
        </div>
      </div>

      {textOverlays.length > 0 && (
        <div className="space-y-2">
          <h3 className="text-sm font-medium text-gray-400">Added Text</h3>
          <div className="space-y-2">
            {textOverlays.map((overlay) => (
              <div
                key={overlay.id}
                className="flex items-center justify-between bg-gray-800 p-2 rounded-lg"
              >
                <span className="truncate" style={{ color: overlay.style.color }}>
                  {overlay.text}
                </span>
                <button
                  onClick={() => onTextRemove(overlay.id)}
                  className="text-red-400 hover:text-red-300"
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