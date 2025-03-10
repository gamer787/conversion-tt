import { supabase } from './supabase';

export interface FriendRequest {
  id: string;
  sender_id: string;
  receiver_id: string;
  status: 'pending' | 'accepted' | 'rejected';
  created_at: string;
  sender?: {
    username: string;
    display_name: string;
    avatar_url: string | null;
  };
  receiver?: {
    username: string;
    display_name: string;
    avatar_url: string | null;
  };
}

export async function sendFriendRequest(receiverId: string) {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('Not authenticated');

    // Check if a request already exists in either direction
    const { data: existingRequests } = await supabase
      .from('friend_requests')
      .select('*')
      .or(
        `and(sender_id.eq.${user.id},receiver_id.eq.${receiverId}),` +
        `and(sender_id.eq.${receiverId},receiver_id.eq.${user.id})`
      );

    if (existingRequests && existingRequests.length > 0) {
      throw new Error('A friend request already exists between these users');
    }

    // Create the friend request
    const { data, error } = await supabase
      .from('friend_requests')
      .insert({
        sender_id: user.id,
        receiver_id: receiverId,
        status: 'pending'
      })
      .select(`
        *,
        sender:sender_id (
          username,
          display_name,
          avatar_url
        ),
        receiver:receiver_id (
          username,
          display_name,
          avatar_url
        )
      `)
      .single();

    if (error) throw error;

    // Send notification if supported
    if ('Notification' in window && Notification.permission === 'granted') {
      const notification = new Notification('Friend Request Sent', {
        body: `Your friend request has been sent to ${data.receiver?.display_name}`,
        icon: data.receiver?.avatar_url || undefined
      });
    }

    return { request: data, error: null };
  } catch (error) {
    return { request: null, error: error instanceof Error ? error.message : 'Failed to send friend request' };
  }
}

export async function respondToFriendRequest(requestId: string, accept: boolean) {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('Not authenticated');

    // First get the request to verify it exists and is pending
    const { data: request, error: requestError } = await supabase
      .from('friend_requests')
      .select('*')
      .eq('id', requestId)
      .eq('receiver_id', user.id)
      .eq('status', 'pending')
      .single();

    if (requestError) throw requestError;
    if (!request) throw new Error('Friend request not found or already processed');

    // Update the request status
    const { data: updatedRequest, error: updateError } = await supabase
      .from('friend_requests')
      .update({ 
        status: accept ? 'accepted' : 'rejected',
        updated_at: new Date().toISOString()
      })
      .eq('id', requestId)
      .eq('receiver_id', user.id)
      .eq('status', 'pending')
      .select(`
        *,
        sender:sender_id (
          username,
          display_name,
          avatar_url
        ),
        receiver:receiver_id (
          username,
          display_name,
          avatar_url
        )
      `)
      .single();

    if (updateError) throw updateError;
    if (!updatedRequest) throw new Error('Failed to update friend request');

    // If accepted, create mutual follows
    if (accept && updatedRequest) {
      // Create mutual follows in a single transaction
      const { error: followError } = await supabase
        .from('follows')
        .upsert([
          { follower_id: updatedRequest.sender_id, following_id: updatedRequest.receiver_id },
          { follower_id: updatedRequest.receiver_id, following_id: updatedRequest.sender_id }
        ]);

      if (followError) throw followError;

      // Send notification if supported
      if ('Notification' in window && Notification.permission === 'granted') {
        const notification = new Notification('Friend Request Accepted', {
          body: `${updatedRequest.receiver?.display_name} accepted your friend request`,
          icon: updatedRequest.receiver?.avatar_url || undefined
        });
      }
    }

    return { request: updatedRequest, error: null };
  } catch (error) {
    return { request: null, error: error instanceof Error ? error.message : 'Failed to respond to friend request' };
  }
}

export async function unfriend(userId: string) {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('Not authenticated');

    // Delete mutual follows in a single transaction
    const { error: unfollowError } = await supabase
      .from('follows')
      .delete()
      .or(
        `and(follower_id.eq.${user.id},following_id.eq.${userId}),` +
        `and(follower_id.eq.${userId},following_id.eq.${user.id})`
      );

    if (unfollowError) throw unfollowError;

    // Delete any existing friend requests
    const { error: requestError } = await supabase
      .from('friend_requests')
      .delete()
      .or(
        `and(sender_id.eq.${user.id},receiver_id.eq.${userId}),` +
        `and(sender_id.eq.${userId},receiver_id.eq.${user.id})`
      );

    if (requestError) throw requestError;

    return { error: null };
  } catch (error) {
    return { error: error instanceof Error ? error.message : 'Failed to unfriend user' };
  }
}

export async function getProfileLinks(profileId: string) {
  try {
    const { data: profile } = await supabase
      .from('profiles')
      .select('account_type')
      .eq('id', profileId)
      .single();

    const isBusinessAccount = profile?.account_type === 'business';

    if (isBusinessAccount) {
      // Use the new SQL function to get followers with badges
      const { data: followers, error: followersError } = await supabase
        .rpc('get_profile_links', {
          profile_id: profileId,
          include_badges: true
        });

      if (followersError) throw followersError;
      return { links: followers || [], error: null };
    } else {
      // Use the new SQL function to get mutual friends with badges
      const { data: friends, error: friendsError } = await supabase
        .rpc('get_profile_links', {
          profile_id: profileId,
          include_badges: true
        });

      if (friendsError) throw friendsError;
      return { links: friends || [], error: null };
    }
  } catch (error) {
    return { links: null, error: error instanceof Error ? error.message : 'Failed to get profile links' };
  }
}

export async function getProfileBrands(profileId: string) {
  try {
    // Get only business accounts that this user follows
    const { data: brands, error: brandsError } = await supabase
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
      .eq('follower_id', profileId)
      .eq('profiles.account_type', 'business');

    if (brandsError) throw brandsError;
    return { brands: brands?.map(b => b.following) || [], error: null };
  } catch (error) {
    return { brands: null, error: error instanceof Error ? error.message : 'Failed to get profile brands' };
  }
}

export async function getProfileStats(profileId: string) {
  try {
    // Get profile type
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('account_type')
      .eq('id', profileId)
      .single();

    if (profileError) throw profileError;

    const isBusinessAccount = profile?.account_type === 'business';

    // Get counts
    const [
      { data: vibes, count: vibesCount, error: vibesError },
      { data: bangers, count: bangersCount, error: bangersError },
      { data: links, count: linksCount, error: linksError },
      { data: brands, count: brandsCount, error: brandsError }
    ] = await Promise.all([
      // Vibes count
      supabase
        .from('posts')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', profileId)
        .eq('type', 'vibe'),
      
      // Bangers count
      supabase
        .from('posts')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', profileId)
        .eq('type', 'banger'),
      
      // Links count
      // For business accounts: count followers
      // For personal accounts: count mutual friends
      isBusinessAccount
        ? supabase
            .from('follows')
            .select('*', { count: 'exact', head: true })
            .eq('following_id', profileId)
        : supabase
            .from('friend_requests')
            .select('*', { count: 'exact', head: true })
            .eq('status', 'accepted')
            .or(`sender_id.eq.${profileId},receiver_id.eq.${profileId}`),
      
      // Brands count (follows where following is a business account)
      supabase
        .from('follows')
        .select('following_id, profiles!follows_following_id_fkey(account_type)', { count: 'exact', head: true })
        .eq('follower_id', profileId)
        .eq('profiles.account_type', 'business')
    ]);

    if (vibesError) throw vibesError;
    if (bangersError) throw bangersError;
    if (linksError) throw linksError;
    if (brandsError) throw brandsError;

    return {
      stats: {
        vibes_count: vibesCount || 0,
        bangers_count: bangersCount || 0,
        links_count: linksCount || 0,
        brands_count: brandsCount || 0
      },
      error: null
    };
  } catch (error) {
    return {
      stats: null,
      error: error instanceof Error ? error.message : 'Failed to get profile stats'
    };
  }
}