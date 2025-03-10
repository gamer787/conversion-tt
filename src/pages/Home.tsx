import React, { useState, useEffect } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { Users } from 'lucide-react';
import { EndlessBangersModal } from '../components/EndlessBangersModal';
import { CommentsModal } from '../components/CommentsModal';
import { DeletePostModal } from '../components/DeletePostModal';
import { supabase } from '../lib/supabase';
import Vibes from '../components/home/Vibes';
import { Bangers } from '../components/home/Bangers';

function Home() {
  const [searchParams] = useSearchParams();
  const showBangers = searchParams.get('view') === 'bangers';
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
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [likedPosts, setLikedPosts] = useState<Set<string>>(new Set());
  const [selectedPost, setSelectedPost] = useState<string | null>(null);
  const [postToDelete, setPostToDelete] = useState<{ id: string; type: 'vibe' | 'banger' } | null>(null);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [showEndlessBangers, setShowEndlessBangers] = useState(false);
  const [lastClickTime, setLastClickTime] = useState<number>(0);
  const [visibleAds, setVisibleAds] = useState<any[]>([]);
  const [adsLoading, setAdsLoading] = useState(true);
  
  const handleBangersClick = (e: React.MouseEvent) => {
    e.preventDefault();
    const currentTime = Date.now();
    const timeDiff = currentTime - lastClickTime;

    if (timeDiff < 300) { // Double click threshold of 300ms
      setShowEndlessBangers(true);
    } else {
      const newParams = new URLSearchParams(searchParams);
      if (searchParams.get('view') === 'bangers') {
        newParams.delete('view');
      } else {
        newParams.set('view', 'bangers');
      }
      window.history.pushState({}, '', `/?${newParams.toString()}`);
    }

    setLastClickTime(currentTime);
  };

  useEffect(() => {
    loadPosts();
    loadVisibleAds();
  }, []);

  useEffect(() => {
    loadLikedPosts();
  }, []);

  useEffect(() => {
    supabase.auth.getUser().then(({ data: { user } }) => {
      setCurrentUserId(user?.id || null);
    });
  }, []);

  async function loadLikedPosts() {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data: likes } = await supabase
        .from('interactions')
        .select('post_id')
        .eq('user_id', user.id)
        .eq('type', 'like');

      setLikedPosts(new Set(likes?.map(like => like.post_id)));
    } catch (error) {
      console.error('Error loading liked posts:', error);
    }
  }

  async function loadVisibleAds() {
    try {
      setAdsLoading(true);
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

      if (!ads) return;

      // Get full ad details
      const { data: fullAds } = await supabase
        .from('ad_campaigns')
        .select(`
          *, content:content_id (
            id, type, content_url, caption, created_at,
            user:user_id (
              username, display_name, avatar_url,
              badge:badge_subscriptions!left (
                role
              )
            )
          )
        `)
        .in('id', ads.map(ad => ad.campaign_id));

      if (!fullAds) return;

      // Get interaction counts
      const { data: interactions } = await supabase
        .from('interactions')
        .select('post_id, type')
        .in('post_id', fullAds.map(ad => ad.content_id));

      // Calculate counts
      const interactionCounts = new Map();
      interactions?.forEach(interaction => {
        const counts = interactionCounts.get(interaction.post_id) || { likes: 0, comments: 0 };
        if (interaction.type === 'like') counts.likes++;
        if (interaction.type === 'comment') counts.comments++;
        interactionCounts.set(interaction.post_id, counts);
      });

      // Combine all data
      const adsWithCounts = fullAds.map(ad => ({
        ...ad,
        content: {
          ...ad.content,
          likes_count: interactionCounts.get(ad.content_id)?.likes || 0,
          comments_count: interactionCounts.get(ad.content_id)?.comments || 0
        }
      }));

      setVisibleAds(adsWithCounts);

      // Increment views for each visible ad
      await Promise.all(
        ads.map(ad =>
          supabase.rpc('increment_ad_views', {
            campaign_id: ad.campaign_id
          })
        )
      );
    } catch (error) {
      console.error('Error loading ads:', error);
    } finally {
      setAdsLoading(false);
    }
  }

  const loadPosts = async () => {
    try {
      setLoading(true);
      setError(null);
      
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      // Get users we can see posts from
      const [{ data: following }, { data: friends }] = await Promise.all([
        // Get followed businesses
        supabase
          .from('follows')
          .select(`
            following:profiles!follows_following_id_fkey (
              id,
              username,
              display_name,
              avatar_url,
              account_type
            )
          `)
          .eq('follower_id', user.id),
        
        // Get accepted friend requests
        supabase
          .from('friend_requests')
          .select(`
            sender:profiles!friend_requests_sender_id_fkey (
              id,
              username,
              display_name,
              avatar_url,
              account_type
            ),
            receiver:profiles!friend_requests_receiver_id_fkey (
              id,
              username,
              display_name,
              avatar_url,
              account_type
            )
          `)
          .eq('status', 'accepted')
          .or(`sender_id.eq.${user.id},receiver_id.eq.${user.id}`)
      ]);

      const businessIds = following?.map(f => f.following.id) || [];
      const friendIds = friends?.map(f => 
        f.sender.id === user.id ? f.receiver.id : f.sender.id
      ) || [];

      // Combine and deduplicate IDs
      const visibleUserIds = [...new Set([
        user.id,
        ...businessIds,
        ...friendIds
      ])];

      if (visibleUserIds.length === 0) {
        setPosts({
          vibes: [],
          bangers: [],
          linkedVibes: [],
          linkedBangers: []
        });
        return;
      }

      // Get posts using the RPC function
      const { data: postsData, error: postsError } = await supabase
        .rpc('get_posts_with_badges', {
          user_ids: visibleUserIds.filter(Boolean)
        });

      if (postsError) throw postsError;

      // Filter posts based on selected tab
      const filteredPosts = postsData?.filter(post => {
        return post.user_info !== null;
      }) || [];

      // Get interaction counts
      const { data: interactions } = await supabase
        .from('interactions')
        .select('post_id, type')
        .in('post_id', filteredPosts.map(p => p.id));

      // Calculate counts
      const interactionCounts = new Map();
      interactions?.forEach(interaction => {
        const counts = interactionCounts.get(interaction.post_id) || { likes: 0, comments: 0 };
        if (interaction.type === 'like') counts.likes++;
        if (interaction.type === 'comment') counts.comments++;
        interactionCounts.set(interaction.post_id, counts);
      });

      // Add counts to posts
      const postsWithCounts = filteredPosts.map(post => ({
        ...post,
        user: post.user_info,
        likes_count: interactionCounts.get(post.id)?.likes || 0,
        comments_count: interactionCounts.get(post.id)?.comments || 0
      }));
      
      // Merge visible ads into appropriate content types
      const vibeAds = visibleAds.filter(ad => ad.content?.type === 'vibe');
      const bangerAds = visibleAds.filter(ad => ad.content?.type === 'banger');

      setPosts({
        vibes: [...postsWithCounts.filter(p => p.type === 'vibe'), ...vibeAds],
        bangers: [...postsWithCounts.filter(p => p.type === 'banger'), ...bangerAds],
        linkedVibes: [],
        linkedBangers: []
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load posts');
    } finally {
      setLoading(false);
    }
  };

  const handleLike = async (postId: string) => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      if (likedPosts.has(postId)) {
        // Unlike the post
        const { error } = await supabase
          .from('interactions')
          .delete()
          .match({
            user_id: user.id,
            post_id: postId,
            type: 'like'
          });

        if (error) throw error;

        // Update UI optimistically
        setLikedPosts(prev => {
          const next = new Set(prev);
          next.delete(postId);
          return next;
        });
        setPosts(prev => ({
          ...prev,
          vibes: prev.vibes.map(post => 
            post.id === postId 
              ? { ...post, likes_count: Math.max(0, post.likes_count - 1) }
              : post
          ),
          bangers: prev.bangers.map(post => 
            post.id === postId 
              ? { ...post, likes_count: Math.max(0, post.likes_count - 1) }
              : post
          )
        }));
        return;
      }

      // Like the post
      const { error } = await supabase
        .from('interactions')
        .insert({
          user_id: user.id,
          post_id: postId,
          type: 'like'
        });

      if (error) throw error;

      setLikedPosts(prev => new Set([...prev, postId]));
      // Update UI optimistically
      setPosts(prev => ({
        ...prev,
        vibes: prev.vibes.map(post => 
          post.id === postId 
            ? { ...post, likes_count: post.likes_count + 1 }
            : post
        ),
        bangers: prev.bangers.map(post => 
          post.id === postId 
            ? { ...post, likes_count: post.likes_count + 1 }
            : post
        )
      }));
    } catch (err) {
      console.error('Error liking post:', err);
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

      setPostToDelete(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete post');
    }
  };

  const updateCommentCount = (postId: string, increment: number) => {
    setPosts(prev => ({
      ...prev,
      vibes: prev.vibes.map(post => 
        post.id === postId 
          ? { ...post, comments_count: post.comments_count + increment }
          : post
      ),
      bangers: prev.bangers.map(post => 
        post.id === postId 
          ? { ...post, comments_count: post.comments_count + increment }
          : post
      )
    }));
  };

  if (loading) {
    return (
      <div className="flex justify-center py-8">
        <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-cyan-400"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-4 bg-red-400/10 text-red-400 rounded-lg">
        {error}
      </div>
    );
  }

  return (
    <div className="pb-20 pt-20 max-w-lg mx-auto px-0">
      {posts.vibes.length === 0 && posts.bangers.length === 0 ? (
          <div className="flex flex-col items-center justify-center text-center p-8 bg-gray-900 rounded-lg">
            <Users className="w-16 h-16 text-cyan-400 mb-4" />
            <h2 className="text-xl font-semibold mb-2">No Content Yet</h2>
            <p className="text-gray-400 mb-4">
              Connect with people to see their vibes and bangers here!
            </p>
            <Link
              to="/find"
              className="bg-cyan-400 text-gray-900 px-6 py-2 rounded-full font-semibold hover:bg-cyan-300 transition-colors"
            >
              Find Connections
            </Link>
          </div>
        ) : (
          <>
            {!showBangers && (
              <Vibes 
                posts={posts.vibes}
                currentUserId={currentUserId}
                likedPosts={likedPosts}
                onLike={handleLike}
                onComment={(postId) => setSelectedPost(postId)}
                onDelete={setPostToDelete}
              />
            )}
            
            {showBangers && (
              <Bangers 
                posts={posts.bangers}
                currentUserId={currentUserId}
                likedPosts={likedPosts}
                onLike={handleLike}
                onComment={(postId) => setSelectedPost(postId)}
                onDelete={setPostToDelete}
              />
            )}
          </>
        )}
      
      {selectedPost && (
        <CommentsModal
          postId={selectedPost}
          onCommentAdded={() => updateCommentCount(selectedPost, 1)}
          onClose={() => setSelectedPost(null)}
        />
      )}
      
      {postToDelete && (
        <DeletePostModal
          type={postToDelete.type}
          onConfirm={handleDeletePost}
          onCancel={() => setPostToDelete(null)}
        />
      )}
      
      {showEndlessBangers && (
        <EndlessBangersModal onClose={() => setShowEndlessBangers(false)} />
      )}
    </div>
  );
}

export default Home