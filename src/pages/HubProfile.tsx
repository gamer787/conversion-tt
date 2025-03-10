import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { ChevronLeft, Camera, AtSign, User, MapPin, Globe, Building2, Phone, Briefcase } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { updateProfile, checkUsernameAvailability } from '../lib/auth';
import type { Profile } from '../types/database';

function HubProfile() {
  const navigate = useNavigate();
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [usernameAvailable, setUsernameAvailable] = useState<boolean | null>(null);
  const [checkingUsername, setCheckingUsername] = useState(false);
  const [originalUsername, setOriginalUsername] = useState<string>('');

  useEffect(() => {
    loadProfile();
  }, []);

  useEffect(() => {
    if (profile?.username === originalUsername) {
      setUsernameAvailable(null);
      return;
    }
    
    const checkUsername = async () => {
      if (!profile?.username || profile.username.length < 3) {
        setUsernameAvailable(null);
        return;
      }

      setCheckingUsername(true);
      const { available } = await checkUsernameAvailability(profile.username);
      setUsernameAvailable(available);
      setCheckingUsername(false);
    };

    const timeoutId = setTimeout(checkUsername, 500);
    return () => clearTimeout(timeoutId);
  }, [profile?.username, originalUsername]);

  const loadProfile = async () => {
    try {
      setLoading(true);
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        navigate('/');
        return;
      }

      const { data: profile } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', user.id)
        .single();

      if (profile) {
        setProfile(profile);
        setOriginalUsername(profile.username);
      }
    } catch (error) {
      console.error('Error loading profile:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    if (!profile) return;
    
    if (profile.username !== originalUsername && !usernameAvailable) {
      setError('Username is not available');
      return;
    }

    try {
      setSaving(true);
      setError(null);
      setSuccess(null);

      const { error } = await updateProfile({
        display_name: profile.display_name,
        username: profile.username,
        bio: profile.bio,
        location: profile.location,
        website: profile.website,
        industry: profile.industry,
        phone: profile.phone,
      });

      if (error) throw error;
      setSuccess('Profile updated successfully');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update profile');
    } finally {
      setSaving(false);
    }
  };

  const handleAvatarUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    try {
      const file = e.target.files?.[0];
      if (!file) return;

      // Validate file size (max 5MB)
      if (file.size > 5 * 1024 * 1024) {
        setError('Image must be less than 5MB');
        return;
      }

      // Validate file type
      if (!['image/jpeg', 'image/png', 'image/gif'].includes(file.type)) {
        setError('Only JPEG, PNG and GIF images are allowed');
        return;
      }

      const fileExt = file.name.split('.').pop();
      const fileName = `${Math.random()}.${fileExt}`;
      const filePath = `avatars/${fileName}`;

      // Delete old avatar if exists
      if (profile?.avatar_url) {
        try {
          const oldPath = profile.avatar_url.split('/').pop();
          if (oldPath) {
            await supabase.storage
              .from('avatars')
              .remove([oldPath]);
          }
        } catch (err) {
          console.error('Error removing old avatar:', err);
        }
      }

      const { error: uploadError } = await supabase.storage
        .from('avatars')
        .upload(filePath, file);

      if (uploadError) throw uploadError;

      const { data: { publicUrl } } = supabase.storage
        .from('avatars')
        .getPublicUrl(filePath);

      // Update profile with new avatar URL
      const { error: updateError } = await supabase
        .from('profiles')
        .update({ avatar_url: publicUrl })
        .eq('id', profile?.id);

      if (updateError) throw updateError;

      setProfile(prev => prev ? { ...prev, avatar_url: publicUrl } : null);
      setSuccess('Profile picture updated successfully');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to upload avatar');
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center py-8">
        <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-cyan-400"></div>
      </div>
    );
  }

  if (!profile) return null;

  return (
    <div className="pb-20 pt-4">
      <div className="flex items-center space-x-3 mb-8">
        <button
          onClick={() => navigate('/hub')}
          className="p-2 hover:bg-gray-800 rounded-lg transition-colors"
        >
          <ChevronLeft className="w-6 h-6" />
        </button>
        <h1 className="text-2xl font-bold">Edit Profile</h1>
      </div>

      {error && (
        <div className="mb-6 p-4 bg-red-400/10 text-red-400 rounded-lg">
          {error}
        </div>
      )}

      {success && (
        <div className="mb-6 p-4 bg-green-400/10 text-green-400 rounded-lg">
          {success}
        </div>
      )}

      <div className="space-y-6">
        {/* Avatar */}
        <div className="flex items-center space-x-6">
          <div className="relative">
            <img
              src={profile.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(profile.display_name)}&background=random`}
              alt={profile.display_name}
              className="w-24 h-24 rounded-full object-cover"
            />
            <label className="absolute bottom-0 right-0 p-2 bg-cyan-400 rounded-full cursor-pointer hover:bg-cyan-300 transition-colors">
              <Camera className="w-4 h-4 text-gray-900" />
              <input
                type="file"
                accept="image/*"
                onChange={handleAvatarUpload}
                className="hidden"
              />
            </label>
          </div>
          <div>
            <h2 className="font-semibold text-lg">{profile.display_name}</h2>
            <p className="text-gray-400">@{profile.username}</p>
          </div>
        </div>

        {/* Basic Info */}
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-1">
              Display Name
            </label>
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <User className="w-5 h-5 text-gray-400" />
              </div>
              <input
                type="text"
                value={profile.display_name}
                onChange={(e) => setProfile(prev => prev ? { ...prev, display_name: e.target.value } : null)}
                className="w-full bg-gray-900 border border-gray-700 rounded-lg pl-10 pr-3 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                placeholder="Your display name"
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-400 mb-1">
              Username
            </label>
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <AtSign className="w-5 h-5 text-gray-400" />
              </div>
              <input
                type="text"
                value={profile.username}
                onChange={(e) => setProfile(prev => prev ? { ...prev, username: e.target.value } : null)}
                className={`w-full bg-gray-900 border rounded-lg pl-10 pr-12 py-2 text-white placeholder-gray-500 focus:outline-none ${
                  profile.username === originalUsername
                    ? 'border-gray-700 focus:border-cyan-400'
                    : usernameAvailable
                    ? 'border-green-500 focus:border-green-500'
                    : 'border-red-500 focus:border-red-500'
                }`}
                placeholder="Your username"
              />
              {profile.username !== originalUsername && profile.username.length >= 3 && (
                <div className="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none">
                  {checkingUsername ? (
                    <div className="animate-spin rounded-full h-5 w-5 border-2 border-gray-400 border-t-transparent" />
                  ) : usernameAvailable ? (
                    <span className="text-green-500">✓</span>
                  ) : (
                    <span className="text-red-500">×</span>
                  )}
                </div>
              )}
            </div>
            {profile.username !== originalUsername && !usernameAvailable && profile.username.length >= 3 && (
              <p className="mt-1 text-sm text-red-500">This username is already taken</p>
            )}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-400 mb-1">
              Bio
            </label>
            <textarea
              value={profile.bio || ''}
              onChange={(e) => setProfile(prev => prev ? { ...prev, bio: e.target.value } : null)}
              className="w-full bg-gray-900 border border-gray-700 rounded-lg p-3 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400 min-h-[100px]"
              placeholder="Tell us about yourself..."
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-400 mb-1">
              Location
            </label>
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <MapPin className="w-5 h-5 text-gray-400" />
              </div>
              <input
                type="text"
                value={profile.location || ''}
                onChange={(e) => setProfile(prev => prev ? { ...prev, location: e.target.value } : null)}
                className="w-full bg-gray-900 border border-gray-700 rounded-lg pl-10 pr-3 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                placeholder="Your location"
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-400 mb-1">
              Website
            </label>
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <Globe className="w-5 h-5 text-gray-400" />
              </div>
              <input
                type="url"
                value={profile.website || ''}
                onChange={(e) => setProfile(prev => prev ? { ...prev, website: e.target.value } : null)}
                className="w-full bg-gray-900 border border-gray-700 rounded-lg pl-10 pr-3 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                placeholder="https://example.com"
              />
            </div>
          </div>

          {profile.account_type === 'business' && (
            <>
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-1">
                  Industry
                </label>
                <div className="relative">
                  <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                    <Briefcase className="w-5 h-5 text-gray-400" />
                  </div>
                  <input
                    type="text"
                    value={profile.industry || ''}
                    onChange={(e) => setProfile(prev => prev ? { ...prev, industry: e.target.value } : null)}
                    className="w-full bg-gray-900 border border-gray-700 rounded-lg pl-10 pr-3 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                    placeholder="Your industry"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-400 mb-1">
                  Business Phone
                </label>
                <div className="relative">
                  <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                    <Phone className="w-5 h-5 text-gray-400" />
                  </div>
                  <input
                    type="tel"
                    value={profile.phone || ''}
                    onChange={(e) => setProfile(prev => prev ? { ...prev, phone: e.target.value } : null)}
                    className="w-full bg-gray-900 border border-gray-700 rounded-lg pl-10 pr-3 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                    placeholder="Your business phone"
                  />
                </div>
              </div>
            </>
          )}
        </div>

        <div className="flex space-x-4">
          <button
            onClick={() => navigate('/hub')}
            className="flex-1 bg-gray-800 text-white px-6 py-3 rounded-lg font-semibold hover:bg-gray-700 transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            disabled={saving}
            className="flex-1 bg-cyan-400 text-gray-900 px-6 py-3 rounded-lg font-semibold hover:bg-cyan-300 transition-colors disabled:opacity-50"
          >
            {saving ? 'Saving...' : 'Save Changes'}
          </button>
        </div>
      </div>
    </div>
  );
}

export default HubProfile;