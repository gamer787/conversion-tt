import React from 'react';
import { Camera } from 'lucide-react';
import type { Profile } from '../../types/database';
import { supabase } from '../../lib/supabase';

interface ProfileHeaderProps {
  profile: Profile;
  isCurrentUser: boolean;
  isEditing: boolean;
  onProfileChange: (updates: Partial<Profile>) => void;
  onSave: () => void;
  onCancel: () => void;
  setError: (error: string | null) => void;
}

export function ProfileHeader({
  profile,
  isCurrentUser,
  isEditing,
  onProfileChange,
  onSave,
  onCancel,
  setError
}: ProfileHeaderProps) {
  return (
    <div className="relative">
      <div className="h-32 bg-gradient-to-r from-purple-500 via-pink-500 to-cyan-500"></div>
      <div className="absolute -bottom-16 left-4">
        <div className="relative group">
          <img
            src={profile.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(profile.display_name)}&background=random`}
            alt={profile.display_name}
            className="w-32 h-32 rounded-full border-4 border-gray-950 object-cover"
          />
          {isEditing && (
            <div className="absolute inset-0 flex items-center justify-center bg-black bg-opacity-50 rounded-full cursor-pointer">
              <label htmlFor="avatar-upload" className="cursor-pointer">
                <Camera className="w-8 h-8 text-white" />
                <input
                  type="file"
                  id="avatar-upload"
                  className="hidden"
                  accept="image/jpeg,image/png,image/gif"
                  onChange={async (e) => {
                    const file = e.target.files?.[0];
                    if (file) {
                      try {
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
                        if (profile.avatar_url) {
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
                          .eq('id', profile.id);

                        if (updateError) throw updateError;

                        onProfileChange({ avatar_url: publicUrl });
                        setError(null);
                      } catch (err) {
                        setError(err instanceof Error ? err.message : 'Failed to upload avatar');
                      }
                    }
                  }}
                />
              </label>
            </div>
          )}
        </div>
      </div>
      <div className="absolute -bottom-16 right-4">
        <div className="flex space-x-2">
          {isEditing ? (
            isCurrentUser && (
              <>
              <button
                onClick={onCancel}
                className="bg-gray-800 text-white px-4 py-2 rounded-full font-semibold hover:bg-gray-700 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={onSave}
                className="bg-cyan-400 text-gray-900 px-6 py-2 rounded-full font-semibold hover:bg-cyan-300 transition-colors"
              >
                Save
              </button>
              </>
            )
          ) : (
            isCurrentUser && (
              <button
                onClick={() => onProfileChange({ isEditing: true })}
                className="bg-cyan-400 text-gray-900 px-6 py-2 rounded-full font-semibold hover:bg-cyan-300 transition-colors"
              >
                Edit Profile
              </button>
            )
          )}
        </div>
      </div>
    </div>
  );
}