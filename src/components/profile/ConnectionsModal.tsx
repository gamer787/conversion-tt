import React, { useState } from 'react';
import { X, UserMinus, AlertTriangle } from 'lucide-react';
import { Link } from 'react-router-dom';
import type { Profile } from '../../types/database';

interface Connection {
  id: string;
  username: string;
  display_name: string;
  avatar_url: string | null;
  account_type: 'personal' | 'business';
  badge?: {
    role: string;
  };
}

interface ConnectionsModalProps {
  type: 'links' | 'brands';
  profile: Profile;
  items: Connection[];
  onUnfollow: (userId: string) => void;
}

export function ConnectionsModal({ type, profile, items, onClose, onUnfollow }: ConnectionsModalProps) {
  const [showUnlinkWarning, setShowUnlinkWarning] = useState<string | null>(null);
  const isBusiness = profile.account_type === 'business';
  const title = type === 'links' ? (isBusiness ? 'Trusts' : 'Links') : 'Brands';

  const handleUnfollow = (userId: string) => {
    setShowUnlinkWarning(userId);
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50 p-4">
      <div className="bg-gray-900 rounded-lg w-full max-w-md">
        <div className="p-4 border-b border-gray-800 flex justify-between items-center">
          <div>
            <h2 className="text-xl font-bold">{title}</h2>
            {isBusiness && type === 'links' && (
              <p className="text-sm text-gray-400 mt-1">Users who trust this business</p>
            )}
          </div>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-white"
          >
            <X className="w-6 h-6" />
          </button>
        </div>
        <div className="max-h-[60vh] overflow-y-auto p-4">
          {items.length === 0 ? (
            <p className="text-center text-gray-400">No {title.toLowerCase()} yet</p>
          ) : (
            <div className="space-y-4">
              {items.map((item) => (
                <div key={item.id} className="flex items-center justify-between bg-gray-800 p-3 rounded-lg">
                  <Link 
                    to={`/profile/${item.username}`} 
                    className="flex items-center space-x-3 flex-1 hover:bg-gray-700 p-2 rounded-lg transition-colors"
                    onClick={onClose}
                  >
                    <img
                      src={item.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(item.display_name)}&background=random`}
                      alt={item.display_name}
                      className="w-12 h-12 rounded-full object-cover"
                    />
                    <div>
                      <p className="font-semibold">{item.display_name}</p>
                      <p className="text-sm text-gray-400">@{item.username}</p>
                      {item.badge && (
                        <span className="inline-block bg-cyan-400/10 text-cyan-400 text-xs px-2 py-0.5 rounded mt-1">
                          {item.badge.role}
                        </span>
                      )}
                      {item.account_type === 'business' && (
                        <span className="inline-block bg-cyan-400/10 text-cyan-400 text-xs px-2 py-0.5 rounded mt-1">
                          Business
                        </span>
                      )}
                    </div>
                  </Link>
                  <button
                    onClick={() => handleUnfollow(item.id)}
                    className="text-red-400 hover:text-red-300 p-2 rounded-full hover:bg-red-400/10 ml-2"
                    title="Unfollow">
                    <UserMinus className="w-5 h-5" />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
        
        {/* Unlink Warning Modal */}
        {showUnlinkWarning && (
          <div className="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-[60] p-4">
            <div className="bg-gray-800 rounded-lg w-full max-w-sm p-6">
              <div className="flex items-center space-x-3 text-yellow-400 mb-4">
                <AlertTriangle className="w-6 h-6" />
                <h3 className="text-lg font-semibold">Unlink Warning</h3>
              </div>
              <p className="text-gray-300 mb-6">
                You will need to meet this person again in real life to re-establish a connection. Are you sure you want to unlink?
              </p>
              <div className="flex space-x-3">
                <button
                  onClick={() => setShowUnlinkWarning(null)}
                  className="flex-1 py-2 px-4 bg-gray-700 text-white rounded-lg hover:bg-gray-600 transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={() => {
                    onUnfollow(showUnlinkWarning);
                    setShowUnlinkWarning(null);
                  }}
                  className="flex-1 py-2 px-4 bg-red-500 text-white rounded-lg hover:bg-red-600 transition-colors"
                >
                  Unlink
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}