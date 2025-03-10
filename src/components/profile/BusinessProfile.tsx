import React from 'react';
import { Building2, Phone, Globe, MapPin } from 'lucide-react';
import type { Profile } from '../../types/database';

interface BusinessProfileProps {
  profile: Profile;
  isEditing: boolean;
  onProfileChange: (updates: Partial<Profile>) => void;
}

export function BusinessProfile({ profile, isEditing, onProfileChange }: BusinessProfileProps) {
  return (
    <div className="space-y-4 mt-4">
      {/* Business-specific fields */}
      {isEditing ? (
        <>
          <div>
            <label htmlFor="industry" className="block text-sm font-medium text-gray-400 mb-1">
              Industry
            </label>
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <Building2 className="w-5 h-5 text-gray-400" />
              </div>
              <input
                id="industry"
                type="text"
                value={profile.industry || ''}
                onChange={(e) => onProfileChange({ industry: e.target.value })}
                className="w-full bg-gray-900 border border-gray-700 rounded-lg pl-10 pr-3 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                placeholder="e.g., Technology, Retail, Services"
                required
              />
            </div>
          </div>

          <div>
            <label htmlFor="phone" className="block text-sm font-medium text-gray-400 mb-1">
              Business Phone
            </label>
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <Phone className="w-5 h-5 text-gray-400" />
              </div>
              <input
                id="phone"
                type="tel"
                value={profile.phone || ''}
                onChange={(e) => onProfileChange({ phone: e.target.value })}
                className="w-full bg-gray-900 border border-gray-700 rounded-lg pl-10 pr-3 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                placeholder="Business phone number"
                required
              />
            </div>
          </div>

          <div>
            <label htmlFor="location" className="block text-sm font-medium text-gray-400 mb-1">
              Business Location
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
                placeholder="Business location"
                required
              />
            </div>
          </div>

          <div>
            <label htmlFor="website" className="block text-sm font-medium text-gray-400 mb-1">
              Business Website
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
              Business Description
            </label>
            <textarea
              id="bio"
              value={profile.bio || ''}
              onChange={(e) => onProfileChange({ bio: e.target.value })}
              className="w-full bg-gray-900 border border-gray-700 rounded-lg p-3 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400 min-h-[100px]"
              placeholder="Tell us about your business..."
              required
            />
          </div>
        </>
      ) : (
        <>
          {profile.bio && (
            <p className="text-gray-200 whitespace-pre-wrap mb-4">{profile.bio}</p>
          )}
          {profile.industry && (
            <div className="flex items-center space-x-2">
              <Building2 className="w-5 h-5 text-cyan-400" />
              <span className="text-gray-200">{profile.industry}</span>
            </div>
          )}
          {profile.phone && (
            <div className="flex items-center space-x-2">
              <Phone className="w-5 h-5 text-cyan-400" />
              <span className="text-gray-200">{profile.phone}</span>
            </div>
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
              <a
                href={profile.website}
                target="_blank"
                rel="noopener noreferrer"
                className="text-cyan-400 hover:underline"
              >
                {new URL(profile.website).hostname}
              </a>
            </div>
          )}
        </>
      )}
    </div>
  );
}