import React, { useState } from 'react';
import { Sliders, Sparkles, Type, Sticker, Music2, Mic } from 'lucide-react';
import { motion } from 'framer-motion';
import { AdjustmentTools } from './AdjustmentTools';
import { FilterTools } from './FilterTools';
import { TextTools } from './TextTools';
import { StickerTools } from './StickerTools';
import { MusicTools } from './MusicTools';
import { VoiceTools } from './VoiceTools';
import ReactEasyCrop from 'react-easy-crop';

interface EditToolsProps {
  selectedType: 'vibe' | 'banger';
  files: File[];
  previews: string[];
  currentIndex: number;
  onNextFile: () => void;
  editStates: any[];
  updateEditState: (updates: any) => void;
}

export function EditTools({
  selectedType,
  files,
  previews,
  currentIndex,
  onNextFile,
  editStates,
  updateEditState
}: EditToolsProps) {
  const [activeTool, setActiveTool] = useState<string | null>(null);
  const [crop, setCrop] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const currentEditState = editStates[currentIndex];

  // Handle text dragging
  const handleTextDrag = (id: string, info: any) => {
    const container = document.querySelector('.preview-container');
    if (!container) return;
    const rect = container.getBoundingClientRect();
    
    // Calculate position as percentage of container dimensions
    let x = ((info.point.x - rect.left) / rect.width) * 100;
    let y = ((info.point.y - rect.top) / rect.height) * 100;
    
    // Clamp values between 0 and 100
    x = Math.max(0, Math.min(100, x));
    y = Math.max(0, Math.min(100, y));

    updateEditState({
      ...currentEditState,
      textOverlays: currentEditState.textOverlays.map((overlay: any) => {
        if (overlay.id === id) {
          return {
            ...overlay,
            position: { x, y }
          };
        }
        return overlay;
      })
    });
  };

  const getImageStyle = () => {
    const { adjustments, selectedFilter } = currentEditState;
    const filters = [];
    
    if (adjustments) {
      if (adjustments.brightness !== 0) filters.push(`brightness(${100 + adjustments.brightness}%)`);
      if (adjustments.contrast !== 0) filters.push(`contrast(${100 + adjustments.contrast}%)`);
      if (adjustments.saturation !== 0) filters.push(`saturate(${100 + adjustments.saturation}%)`);
    }
    
    if (selectedFilter === 'grayscale') filters.push('grayscale(100%)');
    if (selectedFilter === 'sepia') filters.push('sepia(100%)');
    
    return {
      filter: filters.join(' ')
    };
  };

  return (
    <div className="space-y-4">
      {/* File Progress */}
      <div className="flex items-center justify-between text-sm text-gray-400 mb-2">
        <span>Editing {currentIndex + 1} of {files.length}</span>
        {currentIndex < files.length - 1 && (
          <button
            onClick={onNextFile}
            className="text-cyan-400 hover:text-cyan-300"
          >
            Next File →
          </button>
        )}
      </div>

      {/* Tools Bar */}
      <div className="flex space-x-4 overflow-x-auto bg-gray-900 rounded-lg p-4">
        <button 
          onClick={() => setActiveTool(activeTool === 'adjust' ? null : 'adjust')}
          className={`flex flex-col items-center space-y-1 min-w-[64px] ${
            activeTool === 'adjust' ? 'text-cyan-400' : 'text-gray-400'
          }`}
        >
          <div className="w-8 h-8 bg-cyan-400/10 rounded-full flex items-center justify-center">
            <Sliders className="w-5 h-5 text-cyan-400" />
          </div>
          <span className="text-xs">Adjust</span>
        </button>

        <button 
          onClick={() => setActiveTool(activeTool === 'filters' ? null : 'filters')}
          className={`flex flex-col items-center space-y-1 min-w-[64px] ${
            activeTool === 'filters' ? 'text-cyan-400' : 'text-gray-400'
          }`}
        >
          <div className="w-8 h-8 bg-cyan-400/10 rounded-full flex items-center justify-center">
            <Sparkles className="w-5 h-5 text-cyan-400" />
          </div>
          <span className="text-xs">Filters</span>
        </button>

        <button 
          onClick={() => setActiveTool(activeTool === 'text' ? null : 'text')}
          className={`flex flex-col items-center space-y-1 min-w-[64px] ${
            activeTool === 'text' ? 'text-cyan-400' : 'text-gray-400'
          }`}
        >
          <div className="w-8 h-8 bg-cyan-400/10 rounded-full flex items-center justify-center">
            <Type className="w-5 h-5 text-cyan-400" />
          </div>
          <span className="text-xs">Text</span>
        </button>

        <button 
          onClick={() => setActiveTool(activeTool === 'stickers' ? null : 'stickers')}
          className={`flex flex-col items-center space-y-1 min-w-[64px] ${
            activeTool === 'stickers' ? 'text-cyan-400' : 'text-gray-400'
          }`}
        >
          <div className="w-8 h-8 bg-cyan-400/10 rounded-full flex items-center justify-center">
            <Sticker className="w-5 h-5 text-cyan-400" />
          </div>
          <span className="text-xs">Stickers</span>
        </button>

        {selectedType === 'banger' && (
          <>
            <button 
              onClick={() => setActiveTool(activeTool === 'music' ? null : 'music')}
              className={`flex flex-col items-center space-y-1 min-w-[64px] ${
                activeTool === 'music' ? 'text-cyan-400' : 'text-gray-400'
              }`}
            >
              <div className="w-8 h-8 bg-cyan-400/10 rounded-full flex items-center justify-center">
                <Music2 className="w-5 h-5 text-cyan-400" />
              </div>
              <span className="text-xs">Music</span>
            </button>

            <button 
              onClick={() => setActiveTool(activeTool === 'voice' ? null : 'voice')}
              className={`flex flex-col items-center space-y-1 min-w-[64px] ${
                activeTool === 'voice' ? 'text-cyan-400' : 'text-gray-400'
              }`}
            >
              <div className="w-8 h-8 bg-cyan-400/10 rounded-full flex items-center justify-center">
                <Mic className="w-5 h-5 text-cyan-400" />
              </div>
              <span className="text-xs">Voice</span>
            </button>
          </>
        )}
      </div>

      {/* Active Tool Panel */}
      {activeTool === 'adjust' && (
        <AdjustmentTools
          adjustments={currentEditState.adjustments}
          onAdjustmentChange={(adjustments) => 
            updateEditState({ adjustments })
          }
        />
      )}

      {activeTool === 'filters' && (
        <FilterTools
          selectedFilter={currentEditState.selectedFilter}
          onFilterSelect={(filter) =>
            updateEditState({ selectedFilter: filter })
          }
        />
      )}

      {activeTool === 'text' && (
        <TextTools
          textOverlays={currentEditState.textOverlays}
          onTextAdd={(text) =>
            updateEditState({
              textOverlays: [...currentEditState.textOverlays, text]
            })
          }
          onTextUpdate={(id, text) =>
            updateEditState({
              textOverlays: currentEditState.textOverlays.map((t: any) =>
                t.id === id ? text : t
              )
            })
          }
          onTextRemove={(id) =>
            updateEditState({
              textOverlays: currentEditState.textOverlays.filter((t: any) => t.id !== id)
            })
          }
        />
      )}

      {activeTool === 'stickers' && (
        <StickerTools
          selectedStickers={currentEditState.selectedStickers}
          onStickerAdd={(sticker) =>
            updateEditState({
              selectedStickers: [...currentEditState.selectedStickers, sticker]
            })
          }
          onStickerRemove={(id) =>
            updateEditState({
              selectedStickers: currentEditState.selectedStickers.filter((s: any) => s.id !== id)
            })
          }
        />
      )}

      {/* Preview Area */}
      <div className="relative aspect-square bg-black rounded-lg overflow-hidden preview-container">
        <div className="absolute inset-0">
          <ReactEasyCrop
            image={previews[currentIndex]}
            crop={crop}
            zoom={zoom}
            aspect={1}
            onCropChange={setCrop}
            onZoomChange={setZoom}
            style={getImageStyle()}
          />
        </div>

        {/* Text Overlays */}
        {currentEditState.textOverlays.map((overlay: any) => (
          <motion.div
            key={overlay.id}
            drag
            dragMomentum={false}
            dragConstraints={document.querySelector('.preview-container')}
            dragElastic={0}
            onDragEnd={(_, info) => handleTextDrag(overlay.id, info)}
            initial={false}
            style={{
              position: 'absolute',
              left: `${overlay.position.x}%`,
              top: `${overlay.position.y}%`,
              transform: 'translate(-50%, -50%)',
              color: overlay.style.color,
              fontSize: `${overlay.style.fontSize}px`,
              fontFamily: overlay.style.fontFamily,
              cursor: 'move',
              zIndex: 10,
              userSelect: 'none',
              WebkitUserSelect: 'none'
            }}
          >
            {overlay.text}
          </motion.div>
        ))}

        {/* Stickers */}
        {currentEditState.selectedStickers.map((sticker: any) => (
          <motion.div
            key={sticker.id}
            drag
            dragMomentum={false}
            onDragEnd={(_, info) => {
              const container = document.querySelector('.preview-container');
              if (!container) return;
              const rect = container.getBoundingClientRect();
              const x = (info.point.x - rect.left) / rect.width * 100;
              const y = (info.point.y - rect.top) / rect.height * 100;
              updateEditState({
                selectedStickers: currentEditState.selectedStickers.map((s: any) =>
                  s.id === sticker.id
                    ? { ...s, position: { x, y } }
                    : s
                )
              });
            }}
            style={{
              position: 'absolute',
              left: `${sticker.position.x}%`,
              top: `${sticker.position.y}%`,
              transform: `translate(-50%, -50%) scale(${sticker.scale}) rotate(${sticker.rotation}deg)`,
              cursor: 'move'
            }}
          >
            {sticker.url}
          </motion.div>
        ))}
      </div>
    </div>
  );
}