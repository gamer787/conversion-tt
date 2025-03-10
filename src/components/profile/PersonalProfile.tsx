import React from 'react';
import { MapPin, Globe } from 'lucide-react';
import type { Profile } from '../../types/database'; 

interface PersonalProfileProps {
  profile: Profile;
  isEditing: boolean;
}

export function PersonalProfile({ profile, isEditing, onProfileChange }: PersonalProfileProps) {
  return (
    <div className="space-y-4 mt-4">
      {isEditing ? (
        <>
          <div>
            <label htmlFor="location" className="block text-sm font-medium text-gray-400 mb-1">
              Location
            </label>
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <MapPin className="w-5 h-5 text-gray-400" />
              </div>
              <input
                id="location"
                type="text"
                value={profile.location || ''}
                onChange={(e) => onProfileChange({ location: e.target.value })}
                className="w-full bg-gray-900 border border-gray-700 rounded-lg pl-10 pr-3 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                placeholder="Your location"
              />
            </div>
          </div>

          <div>
            <label htmlFor="website" className="block text-sm font-medium text-gray-400 mb-1">
              Website
            </label>
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <Globe className="w-5 h-5 text-gray-400" />
              </div>
              <input
                id="website"
                type="url"
                value={profile.website || ''}
                onChange={(e) => onProfileChange({ website: e.target.value })}
                className="w-full bg-gray-900 border border-gray-700 rounded-lg pl-10 pr-3 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                placeholder="https://example.com"
              />
            </div>
          </div>

          <div>
            <label htmlFor="bio" className="block text-sm font-medium text-gray-400 mb-1">
              Bio
            </label>
            <textarea
              id="bio"
              value={profile.bio || ''}
              onChange={(e) => onProfileChange({ bio: e.target.value })}
              className="w-full bg-gray-900 border border-gray-700 rounded-lg p-3 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400 min-h-[100px]"
              placeholder="Tell us about yourself..."
            />
          </div>
        </>
      ) : (
        <>
          {profile.bio && (
            <p className="text-gray-200 whitespace-pre-wrap mb-4">{profile.bio}</p>
          )}
          {profile.location && (
            <div className="flex items-center space-x-2">
              <MapPin className="w-5 h-5 text-cyan-400" />
              <span className="text-gray-200">{profile.location}</span>
            </div>
          )}
          {profile.website && (
            <div className="flex items-center space-x-2">
              <Globe className="w-5 h-5 text-cyan-400" />
              {(() => {
                try {
                  const url = new URL(profile.website.startsWith('http') ? profile.website : `https://${profile.website}`);
                  return (
                    <a
                      href={url.href}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-cyan-400 hover:underline"
                    >
                      {url.hostname}
                    </a>
                  );
                } catch (e) {
                  return <span className="text-gray-400">{profile.website}</span>;
                }
              })()}
            </div>
          )}
        </>
      )}
    </div>
  );
}