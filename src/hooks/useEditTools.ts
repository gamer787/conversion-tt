import { useState } from 'react';

interface Point {
  x: number;
  y: number;
}

interface TextOverlay {
  id: string;
  text: string;
  position: Point;
  style: {
    fontSize: number;
    color: string;
    fontFamily: string;
  };
}

interface Sticker {
  id: string;
  url: string;
  position: Point;
  scale: number;
  rotation: number;
}

interface EditState {
  crop: Point;
  zoom: number;
  rotation: number;
  selectedFilter: string;
  adjustments: {
    brightness: number;
    contrast: number;
    saturation: number;
  };
  textOverlays: TextOverlay[];
  selectedStickers: Sticker[];
  selectedMusic: {
    url: string;
    title: string;
    artist: string;
    startTime: number;
    duration: number;
  } | null;
  voiceOver: {
    url: string;
    duration: number;
  } | null;
}

export function useEditTools() {
  const [editStates, setEditStates] = useState<EditState[]>([{
    crop: { x: 0, y: 0 },
    zoom: 1,
    rotation: 0,
    selectedFilter: '',
    adjustments: {
      brightness: 0,
      contrast: 0,
      saturation: 0
    },
    textOverlays: [],
    selectedStickers: [],
    selectedMusic: null,
    voiceOver: null
  }]);

  const [currentIndex, setCurrentIndex] = useState(0);

  const addEditState = () => {
    setEditStates(prev => [...prev, {
      crop: { x: 0, y: 0 },
      zoom: 1,
      rotation: 0,
      selectedFilter: '',
      adjustments: {
        brightness: 0,
        contrast: 0,
        saturation: 0
      },
      textOverlays: [],
      selectedStickers: [],
      selectedMusic: null,
      voiceOver: null
    }]);
  };

  const resetEdits = () => {
    setEditStates([{
      crop: { x: 0, y: 0 },
      zoom: 1,
      rotation: 0,
      selectedFilter: '',
      adjustments: {
        brightness: 0,
        contrast: 0,
        saturation: 0
      },
      textOverlays: [],
      selectedStickers: [],
      selectedMusic: null,
      voiceOver: null
    }]);
    setCurrentIndex(0);
  };

  return {
    editStates,
    setEditStates,
    currentIndex,
    setCurrentIndex,
    addEditState,
    resetEdits,
    currentEditState: editStates[currentIndex],
    updateCurrentEditState: (updates: Partial<EditState>) => {
      setEditStates(prev => {
        const newStates = [...prev];
        newStates[currentIndex] = { ...newStates[currentIndex], ...updates };
        return newStates;
      });
    }
  };
}