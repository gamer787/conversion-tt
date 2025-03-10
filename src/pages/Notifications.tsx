import React, { useState, useEffect } from 'react';
import { UserPlus, Heart, MessageCircle, AtSign } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { format } from 'date-fns';
import { FriendRequestModal } from '../components/FriendRequestModal';
import { respondToFriendRequest } from '../lib/friends';
import type { FriendRequest } from '../lib/friends';

function Notifications() {
  const [notifications, setNotifications] = useState<any[]>([]);
  const [friendRequests, setFriendRequests] = useState<FriendRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedRequest, setSelectedRequest] = useState<FriendRequest | null>(null);

  useEffect(() => {
    loadNotifications();
    const interval = setInterval(loadNotifications, 30000); // Refresh every 30 seconds
    return () => clearInterval(interval);
  }, []);

  async function loadNotifications() {
    try {
      setLoading(true);
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      // Get friend requests
      const { data: requests, error: requestsError } = await supabase
        .from('friend_requests')
        .select(`
          *,
          sender:sender_id (
            username,
            display_name,
            avatar_url
          )
        `)
        .eq('receiver_id', user.id)
        .eq('status', 'pending')
        .order('created_at', { ascending: false });

      if (requestsError) throw requestsError;
      setFriendRequests(requests || []);

      // In a real app, you would fetch other types of notifications here
      // For now, we'll just show friend requests
      setNotifications([]);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load notifications');
    } finally {
      setLoading(false);
    }
  }

  const handleAcceptRequest = async (request: FriendRequest) => {
    try {
      setError(null);
      const { error } = await respondToFriendRequest(request.id, true);
      if (error) throw error;
      
      // Show success message
      setError('Friend request accepted successfully!');
      
      // Reload notifications
      await loadNotifications();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to accept friend request');
    }
    setSelectedRequest(null);
  };

  const handleRejectRequest = async (request: FriendRequest) => {
    try {
      setError(null);
      const { error } = await respondToFriendRequest(request.id, false);
      if (error) throw error;
      
      // Show success message
      setError('Friend request rejected');
      
      // Reload notifications
      await loadNotifications();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to reject friend request');
    }
    setSelectedRequest(null);
  };

  if (loading) {
    return (
      <div className="flex justify-center items-center min-h-[50vh]">
        <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-cyan-400"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-4 bg-red-400/10 text-red-400 rounded-lg mt-4">
        {error}
      </div>
    );
  }

  return (
    <div className="pb-20 pt-4">
      <h1 className="text-2xl font-bold mb-6">Notifications</h1>

      {friendRequests.length === 0 && notifications.length === 0 ? (
        <div className="flex flex-col items-center justify-center text-center p-8">
          <p className="text-gray-400">No notifications yet</p>
        </div>
      ) : (
        <div className="space-y-4">
          {/* Friend Requests Section */}
          {friendRequests.map((request) => (
            <div
              key={request.id}
              className="bg-gray-900 p-4 rounded-lg flex items-center justify-between"
            >
              <div className="flex items-center space-x-4">
                <div className="bg-cyan-400/10 p-2 rounded-full">
                  <UserPlus className="w-6 h-6 text-cyan-400" />
                </div>
                <div>
                  <div className="flex items-center space-x-2">
                    <span className="font-semibold">{request.sender?.display_name}</span>
                    <span className="text-gray-400">@{request.sender?.username}</span>
                  </div>
                  <p className="text-sm text-gray-400">
                    Sent you a friend request • {format(new Date(request.created_at), 'MMM d, h:mm a')}
                  </p>
                </div>
              </div>
              <div className="flex space-x-2">
                <button
                  onClick={() => setSelectedRequest(request)}
                  className="bg-cyan-400 text-gray-900 px-4 py-2 rounded-lg hover:bg-cyan-300 transition-colors"
                >
                  View
                </button>
              </div>
            </div>
          ))}

          {/* Other notifications would go here */}
        </div>
      )}

      {/* Friend Request Modal */}
      {selectedRequest && (
        <FriendRequestModal
          username={selectedRequest.sender?.username || ''}
          displayName={selectedRequest.sender?.display_name || ''}
          avatarUrl={selectedRequest.sender?.avatar_url}
          onAccept={() => handleAcceptRequest(selectedRequest)}
          onReject={() => handleRejectRequest(selectedRequest)}
          onClose={() => setSelectedRequest(null)}
        />
      )}
    </div>
  );
}

export default Notifications;