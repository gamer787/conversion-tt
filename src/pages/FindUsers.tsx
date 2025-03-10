import React, { useState, useEffect, useCallback } from 'react';
import { Bluetooth, Smartphone, Search, Building2, MapPin, Globe, UserPlus, UserMinus, Users, AtSign } from 'lucide-react';
import { supabase } from '../lib/supabase';
import debounce from 'lodash.debounce';
import { bluetoothScanner, type BluetoothUser } from '../lib/bluetooth';
import { locationDiscovery, type LocationUser } from '../lib/location';
import { nfcScanner } from '../lib/nfc';
import type { NFCUser } from '../lib/nfc';
import { sendFriendRequest } from '../lib/friends';
import { Link, useNavigate } from 'react-router-dom';

interface Business {
  id: string;
  username: string;
  display_name: string;
  avatar_url: string | null;
  location: string | null;
  website: string | null;
  bio: string | null;
  industry: string | null;
  followers_count: number;
  badge?: {
    role: string;
  };
}

interface User {
  id: string;
  username: string;
  display_name: string;
  avatar_url: string | null;
  account_type: 'personal' | 'business';
  location: string | null;
  bio: string | null;
  connection_status?: 'pending' | 'accepted' | 'rejected' | 'incoming';
  badge?: {
    role: string;
  };
}

export default function FindUsers() {
  const navigate = useNavigate();
  const [isBluetoothScanning, setIsBluetoothScanning] = useState(false);
  const [isNfcScanning, setIsNfcScanning] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchType, setSearchType] = useState<'users' | 'businesses'>('users');
  const [users, setUsers] = useState<User[]>([]);
  const [businesses, setBusinesses] = useState<Business[]>([]);
  const [loading, setLoading] = useState(false);
  const [followedBusinesses, setFollowedBusinesses] = useState<Set<string>>(new Set());
  const [error, setError] = useState<string | null>(null);
  const [nearbyUsers, setNearbyUsers] = useState<BluetoothUser[]>([]);
  const [undiscoveredUsers, setUndiscoveredUsers] = useState<LocationUser[]>([]);
  const [isLocationDiscovering, setIsLocationDiscovering] = useState(false);

  // Handle background/foreground state
  useEffect(() => {
    const handleVisibilityChange = () => {
      bluetoothScanner.setBackgroundMode(document.hidden);
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  }, []);

  useEffect(() => {
    // Request notification permission
    if ('Notification' in window) {
      Notification.requestPermission();
    }

    // Start scanning automatically
    startBluetoothScan();

    // Start location discovery if geolocation is available
    if ('geolocation' in navigator) {
      startLocationDiscovery();
    }

    // Clean up scanning on unmount
    return () => {
      bluetoothScanner.stopScanning();
      nfcScanner.stopScanning();
      locationDiscovery.stopDiscovering();
    };
  }, []);

  const startLocationDiscovery = async () => {
    try {
      setIsLocationDiscovering(true);
      setError(null);

      // Set up callbacks
      locationDiscovery.setOnUserDiscovered((user) => {
        setUndiscoveredUsers(prev => {
          const exists = prev.some(u => u.id === user.id);
          if (!exists) {
            return [...prev, user];
          }
          return prev.map(u => u.id === user.id ? user : u);
        });
      });

      locationDiscovery.setOnError((errorMessage) => {
        setError(errorMessage);
      });

      await locationDiscovery.startDiscovering();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to start location discovery');
      setIsLocationDiscovering(false);
    }
  };

  const startBluetoothScan = async () => {
    try {
      setError(null);

      // Set up callbacks
      bluetoothScanner.setOnUserDiscovered((user) => {
        setNearbyUsers(prev => {
          const exists = prev.some(u => u.id === user.id);
          if (!exists) {
            return [...prev, user];
          }
          return prev.map(u => u.id === user.id ? user : u);
        });
      });

      bluetoothScanner.setOnError((errorMessage) => {
        setError(errorMessage);
        setIsBluetoothScanning(false);
      });

      await bluetoothScanner.startScanning(true);
      setIsBluetoothScanning(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to start Bluetooth scanning');
      setIsBluetoothScanning(false);
    }
  };

  const stopBluetoothScan = () => {
    bluetoothScanner.stopScanning();
    setIsBluetoothScanning(false);
  };

  const startNfcScan = async () => {
    try {
      setError(null);
      setIsNfcScanning(true);

      // Set up callbacks
      nfcScanner.setOnUserDiscovered((user) => {
        handleConnect(user.id, true);
      });

      nfcScanner.setOnError((errorMessage) => {
        setError(errorMessage);
        setIsNfcScanning(false);
      });

      await nfcScanner.startScanning();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to start NFC scanning');
      setIsNfcScanning(false);
    }
  };

  const stopNfcScan = () => {
    nfcScanner.stopScanning();
    setIsNfcScanning(false);
  };

  const handleConnect = async (userId: string, autoAccept = false) => {
    try {
      setError(null);
      const { error: requestError } = await sendFriendRequest(userId);
      
      if (requestError) {
        throw requestError;
      }

      if (autoAccept) {
        setError('Connected successfully via NFC!');
      } else {
        setError('Friend request sent successfully!');
      }

      // Update UI to show pending status
      if (searchType === 'users') {
        setUsers(prev => prev.map(user => 
          user.id === userId 
            ? { ...user, connection_status: autoAccept ? 'accepted' : 'pending' }
            : user
        ));
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to send friend request');
    }
  };

  const searchUsers = useCallback(debounce(async (query: string) => {
    if (!query.trim()) {
      setUsers([]);
      return;
    }

    try {
      setLoading(true);
      
      const { data: { user: currentUser } } = await supabase.auth.getUser();
      if (!currentUser) return;

      // Get users with their active badges
      const { data: usersData, error: usersError } = await supabase
        .from('profiles')
        .select(`
          id, username, display_name, avatar_url, account_type, location, bio,
          badge:badge_subscriptions!left (
            role
          )
        `)
        .eq('account_type', 'personal')
        .neq('id', currentUser.id)
        .or(`username.ilike.%${query}%,display_name.ilike.%${query}%`)
        .gte('badge_subscriptions.start_date', 'now()')
        .lte('badge_subscriptions.end_date', 'now()')
        .is('badge_subscriptions.cancelled_at', null)
        .order('username', { ascending: true })
        .limit(20);

      if (usersError) throw usersError;

      // Get friend request statuses
      const { data: requests } = await supabase
        .from('friend_requests')
        .select('*')
        .or(
          `and(sender_id.eq.${currentUser.id},receiver_id.in.(${usersData?.map(u => u.id).join(',')})),` +
          `and(receiver_id.eq.${currentUser.id},sender_id.in.(${usersData?.map(u => u.id).join(',')}))`
        );

      const usersWithStatus = usersData?.map(user => {
        const outgoingRequest = requests?.find(r => 
          r.sender_id === currentUser.id && r.receiver_id === user.id
        );
        const incomingRequest = requests?.find(r => 
          r.sender_id === user.id && r.receiver_id === currentUser.id
        );

        let status;
        if (outgoingRequest) {
          status = outgoingRequest.status;
        } else if (incomingRequest) {
          status = incomingRequest.status === 'pending' ? 'incoming' : incomingRequest.status;
        }

        return {
          ...user,
          connection_status: status
        };
      });

      setUsers(usersWithStatus || []);
    } catch (err) {
      console.error('Error searching users:', err);
    } finally {
      setLoading(false);
    }
  }, 300), []);

  const searchBusinesses = useCallback(debounce(async (query: string) => {
    if (!query.trim()) {
      setBusinesses([]);
      return;
    }

    try {
      setLoading(true);
      
      // Get businesses with their active badges
      const { data: businessesData, error: businessError } = await supabase
        .from('profiles')
        .select(`
          id, username, display_name, avatar_url, location, website, bio, industry,
          badge:badge_subscriptions!left (
            role
          )
        `)
        .eq('account_type', 'business')
        .or(`display_name.ilike.%${query}%,username.ilike.%${query}%,industry.ilike.%${query}%,location.ilike.%${query}%`)
        .gte('badge_subscriptions.start_date', 'now()')
        .lte('badge_subscriptions.end_date', 'now()')
        .is('badge_subscriptions.cancelled_at', null)
        .order('display_name', { ascending: true })
        .limit(20);

      if (businessError) throw businessError;

      const businessesWithCounts = await Promise.all(
        (businessesData || []).map(async (business) => {
          const { count } = await supabase
            .from('follows')
            .select('*', { count: 'exact', head: true })
            .eq('following_id', business.id);

          return {
            ...business,
            followers_count: count || 0
          };
        })
      );

      const { data: { user } } = await supabase.auth.getUser();
      if (user) {
        const { data: followedData } = await supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', user.id)
          .in('following_id', businessesWithCounts.map(b => b.id));

        const followedIds = new Set(followedData?.map(f => f.following_id) || []);
        setFollowedBusinesses(followedIds);
      }

      setBusinesses(businessesWithCounts);
    } catch (err) {
      console.error('Error searching businesses:', err);
    } finally {
      setLoading(false);
    }
  }, 300), []);

  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setSearchQuery(value);
    if (searchType === 'users') {
      searchUsers(value);
    } else {
      searchBusinesses(value);
    }
  };

  const handleFollow = async (businessId: string) => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        console.error('User not authenticated');
        return;
      }

      const { error } = await supabase
        .from('follows')
        .insert({
          follower_id: user.id,
          following_id: businessId
        });

      if (error) throw error;

      setBusinesses(prev => prev.map(business => 
        business.id === businessId 
          ? { ...business, followers_count: business.followers_count + 1 }
          : business
      ));
      setFollowedBusinesses(prev => new Set([...prev, businessId]));
    } catch (err) {
      console.error('Error following business:', err);
    }
  };

  const handleUnfollow = async (businessId: string) => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        console.error('User not authenticated');
        return;
      }

      const { error } = await supabase
        .from('follows')
        .delete()
        .match({
          follower_id: user.id,
          following_id: businessId
        });

      if (error) throw error;

      setBusinesses(prev => prev.map(business => 
        business.id === businessId 
          ? { ...business, followers_count: Math.max(0, business.followers_count - 1) }
          : business
      ));
      setFollowedBusinesses(prev => {
        const newSet = new Set(prev);
        newSet.delete(businessId);
        return newSet;
      });
    } catch (err) {
      console.error('Error unfollowing business:', err);
    }
  };

  const formatWebsiteUrl = (url: string) => {
    try {
      const urlWithProtocol = url.startsWith('http') ? url : `https://${url}`;
      return new URL(urlWithProtocol);
    } catch (e) {
      return null;
    }
  };

  return (
    <div className="pb-20 pt-4">
      <h1 className="text-2xl font-bold mb-4">Discover Nearby</h1>
      
      <div className="space-y-4">
        {/* Bluetooth Scanning */}
        <div className="bg-gray-900 p-4 rounded-lg">
          <div className="flex items-center justify-between mb-2">
            <p className="text-gray-400">
              {isBluetoothScanning ? 'Scanning for nearby users...' : 'Start scanning to find users nearby'}
            </p>
            {isBluetoothScanning && (
              <div className="flex items-center text-sm text-cyan-400">
                <div className="w-2 h-2 bg-cyan-400 rounded-full mr-2 animate-pulse" />
                Active
              </div>
            )}
          </div>
          <button
            onClick={isBluetoothScanning ? stopBluetoothScan : startBluetoothScan}
            className={`w-full p-3 rounded-lg font-semibold flex items-center justify-center space-x-2 transition-colors ${
              isBluetoothScanning 
                ? 'bg-gray-800 text-gray-400 hover:bg-gray-700'
                : 'bg-cyan-400 text-gray-900 hover:bg-cyan-300'
            }`}
          >
            <Bluetooth className="w-5 h-5" />
            <span>{isBluetoothScanning ? 'Stop Scanning' : 'Scan with Bluetooth'}</span>
          </button>
        </div>

        {/* NFC Scanning */}
        <div className="bg-gray-900 p-4 rounded-lg">
          <button
            onClick={isNfcScanning ? stopNfcScan : startNfcScan}
            className={`w-full p-3 rounded-lg font-semibold flex items-center justify-center space-x-2 transition-colors ${
              isNfcScanning 
                ? 'bg-gray-800 text-gray-400 hover:bg-gray-700'
                : 'bg-cyan-400 text-gray-900 hover:bg-cyan-300'
            }`}
          >
            <Smartphone className="w-5 h-5" />
            <span>{isNfcScanning ? 'Stop NFC' : 'Connect with NFC'}</span>
          </button>
        </div>

        {/* Nearby Users Section */}
        <div className="bg-gray-900 p-4 rounded-lg mb-4">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold">Nearby Users</h2>
            {isBluetoothScanning && (
              <div className="flex items-center text-sm text-cyan-400">
                <div className="w-2 h-2 bg-cyan-400 rounded-full mr-2 animate-pulse" />
                Scanning...
              </div>
            )}
          </div>
          
          {nearbyUsers.length > 0 ? (
            <div className="space-y-3">
              {nearbyUsers.map((user) => (
                <div key={user.id} className="bg-gray-800 p-4 rounded-lg flex items-center justify-between">
                  <div className="flex items-center space-x-3">
                    <img
                      src={user.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(user.display_name)}&background=random`}
                      alt={user.display_name}
                      className="w-12 h-12 rounded-full"
                    />
                    <div>
                      <Link 
                        to={`/profile/${user.username}`}
                        className="font-semibold hover:text-cyan-400 transition-colors"
                      >
                        {user.display_name}
                      </Link>
                      <p className="text-sm text-gray-400">@{user.username}</p>
                      {user.badge && (
                        <span className="inline-block bg-cyan-400/10 text-cyan-400 text-xs px-2 py-0.5 rounded mt-1">
                          {user.badge.role}
                        </span>
                      )}
                      {user.is_friend && (
                        <span className="inline-block bg-green-400/10 text-green-400 text-xs px-2 py-0.5 rounded mt-1">
                          Friend
                        </span>
                      )}
                    </div>
                  </div>
                  {!user.is_friend && (
                    <button
                      onClick={() => handleConnect(user.id)}
                      className="bg-cyan-400 text-gray-900 px-6 py-2 rounded-lg hover:bg-cyan-300 transition-colors"
                    >
                      Connect
                    </button>
                  )}
                </div>
              ))}
            </div>
          ) : (
            <div className="text-center text-gray-400 py-8">
              <p>No nearby users discovered</p>
              <p className="text-sm mt-1">
                {isBluetoothScanning 
                  ? 'Searching for people around you...'
                  : 'Start scanning to find people around you'}
              </p>
            </div>
          )}
        </div>

        {/* Undiscovered Nearby Section */}
        <div className="bg-gray-900 p-4 rounded-lg">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h2 className="text-lg font-semibold">Undiscovered Nearby</h2>
              <p className="text-sm text-gray-400">Within 500 feet</p>
            </div>
            {isLocationDiscovering && (
              <div className="flex items-center text-sm text-cyan-400">
                <div className="w-2 h-2 bg-cyan-400 rounded-full mr-2 animate-pulse" />
                Discovering...
              </div>
            )}
          </div>
          
          {undiscoveredUsers.length > 0 ? (
            <div className="space-y-3">
              {undiscoveredUsers.map((user) => (
                <div key={user.id} className="bg-gray-800 p-4 rounded-lg">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center space-x-3">
                      <img
                        src={user.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(user.display_name)}&background=random`}
                        alt={user.display_name}
                        className="w-12 h-12 rounded-full"
                      />
                      <div>
                        <Link 
                          to={`/profile/${user.username}`}
                          className="font-semibold hover:text-cyan-400 transition-colors"
                        >
                          {user.display_name}
                        </Link>
                        <p className="text-sm text-gray-400">@{user.username}</p>
                        {user.badge && (
                          <span className="inline-block bg-cyan-400/10 text-cyan-400 text-xs px-2 py-0.5 rounded mt-1">
                            {user.badge.role}
                          </span>
                        )}
                        <p className="text-xs text-cyan-400 mt-1">
                          {Math.round(user.distance * 3.28084)} feet away
                        </p>
                      </div>
                    </div>
                    <button
                      onClick={() => handleConnect(user.id)}
                      className="bg-cyan-400 text-gray-900 px-6 py-2 rounded-lg hover:bg-cyan-300 transition-colors"
                    >
                      Connect
                    </button>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-center text-gray-400 py-8 space-y-2">
              {!('geolocation' in navigator) ? (
                <p>Location services are not supported by your browser</p>
              ) : !isLocationDiscovering ? (
                <p>Location discovery is not active</p>
              ) : null}
              
              <p>No undiscovered users nearby</p>
            </div>
          )}
        </div>

        {error && (
          <div className={`p-4 rounded-lg ${
            error.includes('success')
              ? 'bg-green-400/10 text-green-400'
              : 'bg-red-400/10 text-red-400'
          }`}>
            {error}
          </div>
        )}

        {/* Search Section */}
        <div className="mt-8">
          <div className="flex space-x-2 mb-4">
            <button
              onClick={() => {
                setSearchType('users');
                setSearchQuery('');
                setUsers([]);
                setBusinesses([]);
              }}
              className={`flex-1 py-2 px-4 rounded-lg font-semibold flex items-center justify-center space-x-2 ${
                searchType === 'users'
                  ? 'bg-cyan-400 text-gray-900'
                  : 'bg-gray-800 text-gray-400'
              }`}
            >
              <Users className="w-5 h-5" />
              <span>Find Users</span>
            </button>
            <button
              onClick={() => {
                setSearchType('businesses');
                setSearchQuery('');
                setUsers([]);
                setBusinesses([]);
              }}
              className={`flex-1 py-2 px-4 rounded-lg font-semibold flex items-center justify-center space-x-2 ${
                searchType === 'businesses'
                  ? 'bg-cyan-400 text-gray-900'
                  : 'bg-gray-800 text-gray-400'
              }`}
            >
              <Building2 className="w-5 h-5" />
              <span>Find Businesses</span>
            </button>
          </div>

          <div className="relative">
            <input
              type="text"
              placeholder={
                searchType === 'users'
                  ? "Search users by name or username..."
                  : "Search businesses by name, industry, or location..."
              }
              value={searchQuery}
              onChange={handleSearchChange}
              className="w-full bg-gray-900 border border-gray-700 rounded-lg pl-10 pr-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
            />
            <Search className="absolute left-3 top-2.5 text-gray-500 w-5 h-5" />
          </div>

          {loading ? (
            <div className="flex justify-center mt-8">
              <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-cyan-400"></div>
            </div>
          ) : searchType === 'users' ? (
            users.length > 0 ? (
              <div className="mt-4 space-y-4">
                {users.map((user) => (
                  <div key={user.id} className="bg-gray-900 p-4 rounded-lg">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center space-x-4">
                        <img
                          src={user.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(user.display_name)}&background=random`}
                          alt={user.display_name}
                          className="w-12 h-12 rounded-full"
                        />
                        <div>
                          <Link 
                            to={`/profile/${user.username}`}
                            className="font-semibold hover:text-cyan-400 transition-colors"
                          >
                            {user.display_name}
                          </Link>
                          <p className="text-gray-400 text-sm">@{user.username}</p>
                          {user.badge && (
                            <span className="inline-block bg-cyan-400/10 text-cyan-400 text-xs px-2 py-0.5 rounded mt-1">
                              {user.badge.role}
                            </span>
                          )}
                          {user.location && (
                            <div className="flex items-center text-gray-400 text-sm mt-1">
                              <MapPin className="w-4 h-4 mr-1" />
                              <span>{user.location}</span>
                            </div>
                          )}
                        </div>
                      </div>
                      {user.connection_status ? (
                        <span className={`px-3 py-1 rounded-full text-sm ${
                          user.connection_status === 'pending'
                            ? 'bg-yellow-400/10 text-yellow-400'
                            : user.connection_status === 'accepted'
                            ? 'bg-green-400/10 text-green-400'
                            : user.connection_status === 'incoming'
                            ? 'bg-blue-400/10 text-blue-400'
                            : 'bg-red-400/10 text-red-400'
                        }`}>
                          {user.connection_status === 'incoming' ? 'Incoming Request' : 
                           user.connection_status.charAt(0).toUpperCase() + user.connection_status.slice(1)}
                        </span>
                      ) : (
                        <button
                          onClick={() => handleConnect(user.id)}
                          className="bg-cyan-400 text-gray-900 px-4 py-2 rounded-lg hover:bg-cyan-300 transition-colors"
                        >
                          Connect
                        </button>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            ) : searchQuery && !loading ? (
              <p className="text-gray-400 text-center mt-8">No users found</p>
            ) : null
          ) : businesses.length > 0 ? (
            <div className="mt-4 space-y-4">
              {businesses.map((business) => (
                <div key={business.id} className="bg-gray-900 p-4 rounded-lg">
                  <div className="flex items-start justify-between">
                    <div className="flex items-start space-x-4">
                      <img
                        src={business.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(business.display_name)}&background=random`}
                        alt={business.display_name}
                        className="w-12 h-12 rounded-full object-cover"
                      />
                      <div>
                        <Link 
                          to={`/profile/${business.username}`}
                          className="font-semibold text-lg hover:text-cyan-400 transition-colors"
                        >
                          {business.display_name}
                        </Link>
                        <p className="text-gray-400 text-sm">@{business.username}</p>
                        {business.badge && (
                          <span className="inline-block bg-cyan-400/10 text-cyan-400 text-xs px-2 py-0.5 rounded mt-1">
                            {business.badge.role}
                          </span>
                        )}
                        {business.industry && (
                          <div className="flex items-center text-gray-400 text-sm mt-1">
                            <Building2 className="w-4 h-4 mr-1" />
                            <span>{business.industry}</span>
                          </div>
                        )}
                        {business.location && (
                          <div className="flex items-center text-gray-400 text-sm mt-1">
                            <MapPin className="w-4 h-4 mr-1" />
                            <span>{business.location}</span>
                          </div>
                        )}
                        {business.website && (
                          <div className="flex items-center text-cyan-400 text-sm mt-1">
                            <Globe className="w-4 h-4 mr-1" />
                            {(() => {
                              const url = formatWebsiteUrl(business.website);
                              return url ? (
                                <a href={url.href} target="_blank" rel="noopener noreferrer" className="hover:underline">
                                  {url.hostname}
                                </a>
                              ) : null;
                            })()}
                          </div>
                        )}
                        {business.bio && (
                          <p className="text-gray-300 text-sm mt-2">{business.bio}</p>
                        )}
                        <p className="text-gray-400 text-sm mt-2">
                          {business.followers_count} {business.followers_count === 1 ? 'follower' : 'followers'}
                        </p>
                      </div>
                    </div>
                    <button
                      onClick={() => followedBusinesses.has(business.id) ? handleUnfollow(business.id) : handleFollow(business.id)}
                      className={
                        followedBusinesses.has(business.id)
                          ? "flex items-center space-x-1 px-4 py-2 rounded-lg transition-colors bg-gray-800 text-gray-400 hover:bg-gray-700"
                          : "flex items-center space-x-1 px-4 py-2 rounded-lg transition-colors bg-cyan-400 text-gray-900 hover:bg-cyan-300"
                      }
                    >
                      {followedBusinesses.has(business.id) ? (
                        <>
                          <UserMinus className="w-5 h-5" />
                          <span>Unfollow</span>
                        </>
                      ) : (
                        <>
                          <UserPlus className="w-5 h-5" />
                          <span>Follow</span>
                        </>
                      )}
                    </button>
                  </div>
                </div>
              ))}
            </div>
          ) : searchQuery && !loading ? (
            <p className="text-gray-400 text-center mt-8">No businesses found</p>
          ) : null}
        </div>
      </div>
      
      {/* Recommendation Note */}
      <div className="mt-8 p-6 bg-gray-900 rounded-lg border border-cyan-400/20">
        <div className="flex items-start space-x-4">
          <Users className="w-8 h-8 text-cyan-400 mt-1" />
          <div>
            <h3 className="text-lg font-semibold text-cyan-400 mb-2">We Here at ZappaLink Recommend</h3>
            <p className="text-gray-300 leading-relaxed">
              Go out and meet new people in person! Real connections happen face-to-face. 
              Instead of searching manually, use our Bluetooth and Location features to discover 
              and link with people around you. Experience the joy of learning about their lives 
              through genuine interactions!
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}