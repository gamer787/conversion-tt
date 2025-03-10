import React from 'react';
import { Sliders } from 'lucide-react';

interface AdjustmentToolsProps {
  adjustments: {
    brightness: number;
    contrast: number;
    saturation: number;
  };
  onAdjustmentChange: (adjustments: {
    brightness: number;
    contrast: number;
    saturation: number;
  }) => void;
}

export function AdjustmentTools({ adjustments, onAdjustmentChange }: AdjustmentToolsProps) {
  return (
    <div className="p-4 space-y-4">
      <div>
        <label className="flex items-center justify-between text-sm mb-2">
          <span>Brightness</span>
          <span>{adjustments.brightness}</span>
        </label>
        <input
          type="range"
          min="-100"
          max="100"
          value={adjustments.brightness}
          onChange={(e) => onAdjustmentChange({
            ...adjustments,
            brightness: parseInt(e.target.value)
          })}
          className="w-full"
        />
      </div>

      <div>
        <label className="flex items-center justify-between text-sm mb-2">
          <span>Contrast</span>
          <span>{adjustments.contrast}</span>
        </label>
        <input
          type="range"
          min="-100"
          max="100"
          value={adjustments.contrast}
          onChange={(e) => onAdjustmentChange({
            ...adjustments,
            contrast: parseInt(e.target.value)
          })}
          className="w-full"
        />
      </div>

      <div>
        <label className="flex items-center justify-between text-sm mb-2">
          <span>Saturation</span>
          <span>{adjustments.saturation}</span>
        </label>
        <input
          type="range"
          min="-100"
          max="100"
          value={adjustments.saturation}
          onChange={(e) => onAdjustmentChange({
            ...adjustments,
            saturation: parseInt(e.target.value)
          })}
          className="w-full"
        />
      </div>
    </div>
  );
}