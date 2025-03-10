import React from 'react';
import { MapPin, Clock } from 'lucide-react';

interface PostDetailsProps {
  caption: string;
  location: string;
  hideCounts: boolean;
  scheduledTime: Date | null;
  onCaptionChange: (caption: string) => void;
  onLocationChange: (location: string) => void;
  onHideCountsChange: (hide: boolean) => void;
  onScheduleChange: (date: Date | null) => void;
  onHashtagsChange: (hashtags: string[]) => void;
  onMentionsChange: (mentions: string[]) => void;
}

export function PostDetails({
  caption,
  location,
  hideCounts,
  scheduledTime,
  onCaptionChange,
  onLocationChange,
  onHideCountsChange,
  onScheduleChange,
  onHashtagsChange,
  onMentionsChange
}: PostDetailsProps) {
  const handleCaptionChange = (text: string) => {
    onCaptionChange(text);
    const words = text.split(/\s+/);
    onHashtagsChange(words.filter(w => w.startsWith('#')).map(w => w.slice(1)));
    onMentionsChange(words.filter(w => w.startsWith('@')).map(w => w.slice(1)));
  };

  return (
    <div className="space-y-6">
      {/* Caption */}
      <div>
        <textarea
          placeholder="Write a caption..."
          value={caption}
          onChange={(e) => handleCaptionChange(e.target.value)}
          className="w-full bg-gray-900 border border-gray-700 rounded-lg p-4 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400 min-h-[150px]"
          maxLength={2200}
        />
        <div className="flex justify-between text-sm text-gray-400 mt-2">
          <span>{caption.length}/2,200</span>
          <span>{caption.split(/\s+/).filter(w => w.startsWith('#')).length}/30 hashtags</span>
        </div>
      </div>

      {/* Location */}
      <div className="relative">
        <MapPin className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
        <input
          type="text"
          placeholder="Add location"
          value={location}
          onChange={(e) => onLocationChange(e.target.value)}
          className="w-full bg-gray-900 border border-gray-700 rounded-lg pl-10 pr-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
        />
      </div>

      {/* Advanced Options */}
      <div className="space-y-4 bg-gray-900 rounded-lg p-4">
        <div className="flex items-center justify-between">
          <span>Hide like and view counts</span>
          <button
            onClick={() => onHideCountsChange(!hideCounts)}
            className={`w-12 h-6 rounded-full transition-colors ${
              hideCounts ? 'bg-cyan-400' : 'bg-gray-700'
            }`}
          >
            <div
              className={`w-5 h-5 bg-white rounded-full transform transition-transform ${
                hideCounts ? 'translate-x-7' : 'translate-x-1'
              }`}
            />
          </button>
        </div>

        <div>
          <button
            onClick={() => {
              const tomorrow = new Date();
              tomorrow.setDate(tomorrow.getDate() + 1);
              tomorrow.setHours(9, 0, 0, 0);
              onScheduleChange(tomorrow);
            }}
            className="flex items-center space-x-2 text-cyan-400"
          >
            <Clock className="w-5 h-5" />
            <span>Schedule post</span>
          </button>
          {scheduledTime && (
            <p className="text-sm text-gray-400 mt-2">
              Will be posted on {scheduledTime.toLocaleDateString()} at{' '}
              {scheduledTime.toLocaleTimeString()}
            </p>
          )}
        </div>
      </div>
    </div>
  );
}