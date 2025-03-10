import React, { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { getCurrentProfile, updateProfile } from '../lib/auth';
import { getProfileLinks, getProfileBrands, getProfileStats } from '../lib/friends';
import type { Profile as ProfileType, Connection } from '../types/database';
import { BusinessProfile } from '../components/profile/BusinessProfile';
import { PersonalProfile } from '../components/profile/PersonalProfile';
import { ProfileStats } from '../components/profile/ProfileStats';
import { ProfileHeader } from '../components/profile/ProfileHeader';
import { ConnectionsModal } from '../components/profile/ConnectionsModal';
import { DeletePostModal } from '../components/DeletePostModal';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '../components/ui/Tabs';
import { ImageIcon, Film, Users, MoreVertical, Trash2 } from 'lucide-react';

function Profile() {
  const { username } = useParams();
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState('vibes');
  const [loading, setLoading] = useState(true);
  const [profile, setProfile] = useState<ProfileType | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isEditing, setIsEditing] = useState<boolean>(false);
  const [stats, setStats] = useState({
    vibes_count: 0,
    bangers_count: 0,
    links_count: 0,
    brands_count: 0
  });
  const [showLinksModal, setShowLinksModal] = useState(false);
  const [showBrandsModal, setShowBrandsModal] = useState(false);
  const [connections, setConnections] = useState<Connection[]>([]);
  const [brands, setBrands] = useState<Connection[]>([]);
  const [postToDelete, setPostToDelete] = useState<{ id: string; type: 'vibe' | 'banger' } | null>(null);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [visibleAds, setVisibleAds] = useState<any[]>([]);
  const [activeBadge, setActiveBadge] = useState<{role: string} | null>(null);
  const [posts, setPosts] = useState<{
    vibes: any[];
    bangers: any[];
    linkedVibes: any[];
    linkedBangers: any[];
  }>({
    vibes: [],
    bangers: [],
    linkedVibes: [],
    linkedBangers: []
  });

  useEffect(() => {
    // Reset editing state when profile changes
    setIsEditing(false);
    loadProfile().then(() => {
      if (profile) {
        loadStats(profile.id);
      }
    });
  }, [username]);

  useEffect(() => {
    if (profile) {
      loadPosts();
      loadStats(profile.id);
      if (profile.account_type === 'business') {
        loadVisibleAds();
      }
    }
  }, [profile?.id, activeTab]);

  const loadStats = async (profileId: string) => {
    try {
      const { stats: profileStats, error } = await getProfileStats(profileId);
      if (error) throw error;
      if (profileStats) {
        setStats(profileStats);
      }
    } catch (err) {
      console.error('Error loading stats:', err);
    }
  };

  useEffect(() => {
    // Get current user's ID
    supabase.auth.getUser().then(({ data: { user } }) => {
      setCurrentUserId(user?.id || null);
    });
  }, []);

  const loadVisibleAds = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      // Get user's location
      const { data: userProfile } = await supabase
        .from('profiles')
        .select('latitude, longitude')
        .eq('id', user.id)
        .single();

      if (!userProfile?.latitude || !userProfile?.longitude) return;

      // Get visible ads based on user's location
      const { data: ads } = await supabase.rpc('get_visible_ads', {
        viewer_lat: userProfile.latitude,
        viewer_lon: userProfile.longitude
      });

      if (ads) {
        // Get full ad details
        const { data: fullAds } = await supabase
          .from('ad_campaigns')
          .select(`
            *,
            content:content_id (
              id,
              type,
              content_url,
              caption
            )
          `)
          .in('id', ads.map(ad => ad.campaign_id));

        setVisibleAds(fullAds || []);

        // Increment views for each visible ad
        await Promise.all(
          ads.map(ad =>
            supabase.rpc('increment_ad_views', {
              campaign_id: ad.campaign_id
            })
          )
        );
      }
    } catch (error) {
      console.error('Error loading ads:', error);
    }
  };

  const loadProfile = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      let profileId;
      setLoading(true);
      
      if (username) {
        const { data: profileData } = await supabase
          .from('profiles')
          .select('id')
          .eq('username', username)
          .single();
        profileId = profileData?.id;
      } else {
        profileId = user?.id;
      }

      if (!profileId) {
        navigate('/');
        return;
      }

      // Get profile
      const { data: profile } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', profileId)
        .single();

      if (profile) {
        setProfile(profile);
        
        // Get active badge
        const { data: badge } = await supabase
          .rpc('get_active_badge', { 
            target_user_id: profileId
          });

        setActiveBadge(badge?.[0] || null);
      }
    } catch (error) {
      console.error('Error loading profile:', error);
    } finally {
      setLoading(false);
    }
  };

  async function loadPosts() {
    if (!profile) return;

    setLoading(true);
    try {
      // Load user's own posts
      const { data: postsData, error: postsError } = await supabase.rpc(
        'get_profile_posts',
        {
          profile_id: profile.id,
          post_type: activeTab === 'vibes' ? 'vibe' : 'banger'
        }
      );

      if (postsError) throw postsError;

      // Transform posts to match expected structure
      const currentTabPosts = (postsData || []).map(post => ({
        ...post,
        user: post.user_info
      }));
      setPosts(prev => ({
        ...prev,
        [activeTab === 'vibes' ? 'vibes' : 'bangers']: currentTabPosts
      }));
      // Load posts from linked users if viewing the links tab
      if (activeTab === 'links') {
        // Get IDs of linked users
        const { links } = await getProfileLinks(profile.id);
        if (links && links.length > 0) {
          const linkedUserIds = links.map(link => link.id);

          // Get vibes from linked users
          const linkedVibes = await Promise.all(
            linkedUserIds.map(userId =>
              supabase.rpc('get_profile_posts', {
                profile_id: userId,
                post_type: 'vibe'
              })
            )
          );

          // Get bangers from linked users
          const linkedBangers = await Promise.all(
            linkedUserIds.map(userId =>
              supabase.rpc('get_profile_posts', {
                profile_id: userId,
                post_type: 'banger'
              })
            )
          );

          // Flatten and transform the results
          const linkedVibesData = linkedVibes
            .flatMap(result => result.data || [])
            .map(post => ({
              ...post,
              user: post.user_info
            }));

          const linkedBangersData = linkedBangers
            .flatMap(result => result.data || [])
            .map(post => ({
              ...post,
              user: post.user_info
            }));

          setPosts(prev => ({
            ...prev,
            linkedVibes: linkedVibesData,
            linkedBangers: linkedBangersData
          }));
        }
      }
    } catch (err) {
      console.error('Error loading posts:', err);
    } finally {
      setLoading(false);
    }
  }

  async function loadConnections(type: 'links' | 'brands') {
    if (!profile) return;

    try {
      if (type === 'links') {
        const { links, error } = await getProfileLinks(profile.id);
        if (error) throw error;
        setConnections(links || []);
      } else {
        const { brands, error } = await getProfileBrands(profile.id);
        if (error) throw error;
        setBrands(brands || []);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : `Failed to load ${type}`);
    }
  }

  const handleSave = async () => {
    if (!profile) return;

    const updates = {
      display_name: profile.display_name,
      bio: profile.bio,
      location: profile.location,
      website: profile.website,
      industry: profile.industry,
      phone: profile.phone,
    };

    try {
      setError(null);
      const { profile: updatedProfile, error } = await updateProfile(updates);

      if (error) throw error;
      
      // Update local state with the updated profile
      if (updatedProfile) {
        setProfile(updatedProfile);
      }
      
      setIsEditing(false);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update profile');
    }
  };

  const handleDeletePost = async () => {
    if (!postToDelete) return;

    try {
      setError(null);

      // Delete the post
      const { error: deleteError } = await supabase
        .from('posts')
        .delete()
        .eq('id', postToDelete.id);

      if (deleteError) throw deleteError;

      // Delete the file from storage
      const { error: storageError } = await supabase.storage
        .from(postToDelete.type === 'vibe' ? 'vibes' : 'bangers')
        .remove([`${currentUserId}/${postToDelete.id}`]);

      if (storageError) {
        console.error('Error deleting file:', storageError);
      }

      // Update UI
      setPosts(prev => ({
        ...prev,
        [postToDelete.type === 'vibe' ? 'vibes' : 'bangers']: prev[postToDelete.type === 'vibe' ? 'vibes' : 'bangers'].filter(
          post => post.id !== postToDelete.id
        )
      }));

      // Update stats
      setStats(prev => ({
        ...prev,
        [`${postToDelete.type}s_count`]: Math.max(0, prev[`${postToDelete.type}s_count`] - 1)
      }));

      setPostToDelete(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete post');
    }
  };

  const handleCancel = () => {
    // Reset profile to last saved state
    loadProfile();
    if (profile) {
      loadStats(profile.id);
    }
    setIsEditing(false);
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-950 flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-cyan-400"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gray-950 flex items-center justify-center">
        <div className="text-red-500">{error}</div>
      </div>
    );
  }

  if (!profile) {
    return (
      <div className="min-h-screen bg-gray-950 flex items-center justify-center">
        <div className="text-gray-400">Profile not found</div>
      </div>
    );
  }

  const isCurrentUser = currentUserId === profile.id;

  return (
    <div className="pb-20 max-w-lg mx-auto px-0 sm:px-4">
      <ProfileHeader
        isCurrentUser={isCurrentUser}
        profile={profile}
        isEditing={isEditing}
        onProfileChange={(updates) => {
          if (updates.isEditing !== undefined) {
            // Only allow setting edit mode if it's the current user's profile
            if (!isCurrentUser) return;
            setIsEditing(updates.isEditing);
          } else {
            setProfile(prev => prev ? { ...prev, ...updates } : null);
          }
        }}
        onSave={handleSave}
        onCancel={handleCancel}
        setError={setError}
      />

      <div className="mt-20 px-4">
        <div className="flex justify-between items-start">
          <div className="flex-1">
            {isEditing ? (
              <div className="space-y-3">
                <input
                  type="text"
                  value={profile.display_name}
                  onChange={(e) => setProfile(prev => prev ? { ...prev, display_name: e.target.value } : null)}
                  className="w-full bg-gray-900 border border-gray-700 rounded-lg px-3 py-2 text-white text-2xl font-bold"
                />
                <p className="text-gray-400">@{profile.username}</p>
              </div>
            ) : (
              <>
                <h1 className="text-2xl font-bold">{profile.display_name}</h1>
                <p className="text-gray-400">@{profile.username}</p>
                {activeBadge && (
                  <div className="mt-2 inline-block bg-cyan-400/10 text-cyan-400 px-3 py-1 rounded-full text-sm font-medium">
                    {activeBadge.role}
                  </div>
                )}
              </>
            )}
          </div>
        </div>

        {profile.account_type === 'business' ? (
          <BusinessProfile
            profile={profile}
            isEditing={isEditing && isCurrentUser}
            onProfileChange={(updates) => setProfile(prev => prev ? { ...prev, ...updates } : null)}
          />
        ) : (
          <PersonalProfile
            profile={profile}
            isEditing={isEditing && isCurrentUser}
            onProfileChange={(updates) => setProfile(prev => prev ? { ...prev, ...updates } : null)}
          />
        )}

        <ProfileStats
          profile={profile}
          stats={stats}
          onShowLinks={() => {
            loadConnections('links');
            setShowLinksModal(true);
          }}
          onShowBrands={() => {
            loadConnections('brands');
            setShowBrandsModal(true);
          }}
        />
      </div>

      <Tabs 
        defaultValue="vibes" 
        value={activeTab}
        onChange={(value) => setActiveTab(value)}
        className="mt-4"
      >
        <TabsList className="flex space-x-1 bg-gray-900 p-1 rounded-none sm:rounded-lg mb-1 sticky top-0 z-10 mx-0 sm:mx-4">
          <TabsTrigger
            value="vibes"
            className="flex-1 flex items-center justify-center space-x-2 transition-colors"
          >
            <ImageIcon className="w-4 h-4" />
            <span>Vibes</span>
          </TabsTrigger>
          <TabsTrigger
            value="bangers"
            className="flex-1 flex items-center justify-center space-x-2 transition-colors"
          >
            <Film className="w-4 h-4" />
            <span>Bangers</span>
          </TabsTrigger>
        </TabsList>

        {/* Links Tab Content */}
        <TabsContent value="links">
          {connections.length > 0 ? (
            <div>
              {/* Links Grid */}
              <div className="grid grid-cols-2 gap-4 px-4 mb-8">
                {connections.map((connection) => (
                  <Link
                    key={connection.id}
                    to={`/profile/${connection.username}`}
                    className="bg-gray-900 p-4 rounded-lg hover:bg-gray-800 transition-colors"
                  >
                    <div className="flex items-center space-x-3">
                      <img
                        src={connection.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(connection.display_name)}&background=random`}
                        alt={connection.display_name}
                        className="w-12 h-12 rounded-full"
                      />
                      <div>
                        <h3 className="font-semibold">{connection.display_name}</h3>
                        <p className="text-sm text-gray-400">@{connection.username}</p>
                      </div>
                    </div>
                  </Link>
                ))}
              </div>

              {/* Linked Users' Content */}
              <div className="mt-8">
                <h2 className="text-xl font-bold px-4 mb-4">Links' Vibes</h2>
                {posts.linkedVibes.length > 0 ? (
                  <div className="grid grid-cols-3 gap-0.5">
                    {posts.linkedVibes.map((post) => (
                      <div key={post.id} className="aspect-square">
                        <img
                          src={post.content_url}
                          alt={post.caption}
                          className="w-full h-full object-cover"
                        />
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="px-4 py-8 text-center text-gray-400 bg-gray-900 mx-4 rounded-lg">
                    <p>No vibes from links yet</p>
                  </div>
                )}

                <h2 className="text-xl font-bold px-4 mb-4 mt-8">Links' Bangers</h2>
                {posts.linkedBangers.length > 0 ? (
                  <div className="grid grid-cols-3 gap-0.5">
                    {posts.linkedBangers.map((post) => (
                      <div key={post.id} className="relative aspect-[9/16] bg-black rounded-lg overflow-hidden">
                        <video
                          src={post.content_url}
                          controls
                          className="absolute inset-0 w-full h-full object-contain"
                        />
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="px-4 py-8 text-center text-gray-400 bg-gray-900 mx-4 rounded-lg">
                    <p>No bangers from links yet</p>
                  </div>
                )}
              </div>
            </div>
          ) : (
            <div className="px-4 py-8 text-center text-gray-400 bg-gray-900 mx-4 rounded-lg">
              <p>No links yet</p>
            </div>
          )}
        </TabsContent>

        <TabsContent value="vibes">
          {posts.vibes.length > 0 ? (
            <div className="grid grid-cols-3 gap-[2px]">
              {posts.vibes.map((post) => (
                <div key={post.id} className="aspect-square relative group">
                  <img
                    src={post.content_url}
                    alt={post.caption}
                    className="w-full h-full object-cover"
                  />
                  {isCurrentUser && (
                    <div className="absolute inset-0 bg-black bg-opacity-50 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                      <button
                        onClick={() => setPostToDelete({ id: post.id, type: 'vibe' })}
                        className="p-2 bg-red-500 rounded-full hover:bg-red-600 transition-colors"
                      >
                        <Trash2 className="w-5 h-5" />
                      </button>
                    </div>
                  )}
                </div>
              ))}
            </div>
          ) : (
            <div className="px-4 py-8 text-center text-gray-400 bg-gray-900 mx-4 rounded-lg">
              <p>No vibes posted yet</p>
            </div>
          )}
        </TabsContent>

        <TabsContent value="bangers">
          {posts.bangers.length > 0 ? (
            <div className="grid grid-cols-3 gap-[2px]">
              {posts.bangers.map((post) => (
                <div key={post.id} className="relative aspect-[9/16] bg-black rounded-lg overflow-hidden group">
                  <video
                    src={post.content_url}
                    controls
                    className="absolute inset-0 w-full h-full object-contain"
                  />
                  {isCurrentUser && (
                    <div className="absolute inset-0 bg-black bg-opacity-50 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center pointer-events-none">
                      <button
                        onClick={() => setPostToDelete({ id: post.id, type: 'banger' })}
                        className="p-2 bg-red-500 rounded-full hover:bg-red-600 transition-colors pointer-events-auto"
                      >
                        <Trash2 className="w-5 h-5" />
                      </button>
                    </div>
                  )}
                </div>
              ))}
            </div>
          ) : (
            <div className="px-4 py-8 text-center text-gray-400 bg-gray-900 mx-4 rounded-lg">
              <p>No bangers posted yet</p>
            </div>
          )}
        </TabsContent>

        {/* Show ads if this is a business profile */}
        {profile.account_type === 'business' && visibleAds.length > 0 && (
          <div className="mb-8">
            <h2 className="text-xl font-bold px-4 mb-4">Promoted Content</h2>
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-4 px-4">
              {visibleAds.map((ad) => (
                <div key={ad.id} className="aspect-square relative group">
                  {ad.content.type === 'vibe' ? (
                    <img
                      src={ad.content.content_url}
                      alt={ad.content.caption}
                      className="w-full h-full object-cover rounded-lg"
                    />
                  ) : (
                    <video
                      src={ad.content.content_url}
                      className="w-full h-full object-cover rounded-lg"
                      controls
                    />
                  )}
                  <div className="absolute inset-0 bg-black bg-opacity-50 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                    <div className="text-center p-4">
                      <p className="text-sm text-cyan-400">Promoted</p>
                      {ad.content.caption && (
                        <p className="text-white mt-2">{ad.content.caption}</p>
                      )}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </Tabs>

      {showLinksModal && (
        <ConnectionsModal
          type="links"
          profile={profile}
          items={connections}
          onClose={() => setShowLinksModal(false)}
          onUnfollow={async (userId) => {
            try {
              const { error } = await supabase
                .from('follows')
                .delete()
                .match({ follower_id: profile.id, following_id: userId });

              if (error) throw error;
              await loadConnections('links');
              await loadProfile(); // Reload stats
            } catch (err) {
              setError(err instanceof Error ? err.message : 'Failed to unfollow user');
            }
          }}
        />
      )}

      {showBrandsModal && (
        <ConnectionsModal
          type="brands"
          profile={profile}
          items={brands}
          onClose={() => setShowBrandsModal(false)}
          onUnfollow={async (userId) => {
            try {
              const { error } = await supabase
                .from('follows')
                .delete()
                .match({ follower_id: profile.id, following_id: userId });

              if (error) throw error;
              await loadConnections('brands');
              await loadProfile(); // Reload stats
            } catch (err) {
              setError(err instanceof Error ? err.message : 'Failed to unfollow business');
            }
          }}
        />
      )}

      {postToDelete && (
        <DeletePostModal
          type={postToDelete.type}
          onConfirm={handleDeletePost}
          onCancel={() => setPostToDelete(null)}
        />
      )}
    </div>
  );
}

export default Profile