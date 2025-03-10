import React, { useState } from 'react';
import { Music2, Search, Play, Pause } from 'lucide-react';

interface MusicToolsProps {
  selectedMusic: {
    url: string;
    title: string;
    artist: string;
    startTime: number;
    duration: number;
  } | null;
  onMusicSelect: (music: {
    url: string;
    title: string;
    artist: string;
    startTime: number;
    duration: number;
  } | null) => void;
}

// Example music library
const MUSIC_LIBRARY = [
  {
    id: '1',
    title: 'Summer Vibes',
    artist: 'Chill Beats',
    duration: 180,
    url: 'https://example.com/music1.mp3'
  },
  {
    id: '2',
    title: 'Urban Flow',
    artist: 'City Sounds',
    duration: 210,
    url: 'https://example.com/music2.mp3'
  },
  // Add more tracks as needed
];

export function MusicTools({ selectedMusic, onMusicSelect }: MusicToolsProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [isPlaying, setIsPlaying] = useState(false);
  const [startTime, setStartTime] = useState(0);

  const filteredMusic = MUSIC_LIBRARY.filter(
    track =>
      track.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      track.artist.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  return (
    <div className="p-4 space-y-4">
      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-5 h-5" />
        <input
          type="text"
          placeholder="Search music..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="w-full bg-gray-800 border border-gray-700 rounded-lg pl-10 pr-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
        />
      </div>

      <div className="space-y-2">
        {filteredMusic.map((track) => (
          <div
            key={track.id}
            className={`p-4 rounded-lg ${
              selectedMusic?.url === track.url
                ? 'bg-cyan-400/10 border border-cyan-400'
                : 'bg-gray-800 hover:bg-gray-700'
            }`}
          >
            <div className="flex items-center justify-between">
              <div>
                <h3 className="font-medium">{track.title}</h3>
                <p className="text-sm text-gray-400">{track.artist}</p>
              </div>
              <button
                onClick={() => {
                  if (selectedMusic?.url === track.url) {
                    setIsPlaying(!isPlaying);
                  } else {
                    onMusicSelect({
                      ...track,
                      startTime: 0
                    });
                    setIsPlaying(true);
                  }
                }}
                className="p-2 rounded-full hover:bg-gray-600"
              >
                {selectedMusic?.url === track.url && isPlaying ? (
                  <Pause className="w-5 h-5" />
                ) : (
                  <Play className="w-5 h-5" />
                )}
              </button>
            </div>

            {selectedMusic?.url === track.url && (
              <div className="mt-4 space-y-2">
                <input
                  type="range"
                  min="0"
                  max={track.duration}
                  value={startTime}
                  onChange={(e) => {
                    const newTime = parseInt(e.target.value);
                    setStartTime(newTime);
                    onMusicSelect({
                      ...track,
                      startTime: newTime
                    });
                  }}
                  className="w-full"
                />
                <div className="flex justify-between text-sm text-gray-400">
                  <span>{formatTime(startTime)}</span>
                  <span>{formatTime(track.duration)}</span>
                </div>
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}