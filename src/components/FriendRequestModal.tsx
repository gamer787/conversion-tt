import React from 'react';
import { X } from 'lucide-react';

interface FriendRequestModalProps {
  username: string;
  displayName: string;
  avatarUrl: string | null;
  onAccept: () => void;
  onReject: () => void;
  onClose: () => void;
}

export function FriendRequestModal({
  username,
  displayName,
  avatarUrl,
  onAccept,
  onReject,
  onClose
}: FriendRequestModalProps) {
  return (
    <div className="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50 p-4">
      <div className="bg-gray-900 rounded-lg w-full max-w-md">
        <div className="p-4 border-b border-gray-800 flex justify-between items-center">
          <h2 className="text-xl font-bold">Friend Request</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-white">
            <X className="w-6 h-6" />
          </button>
        </div>
        <div className="p-6">
          <div className="flex items-center space-x-4 mb-6">
            <img
              src={avatarUrl || `https://ui-avatars.com/api/?name=${encodeURIComponent(displayName)}&background=random`}
              alt={displayName}
              className="w-16 h-16 rounded-full"
            />
            <div>
              <h3 className="font-semibold text-lg">{displayName}</h3>
              <p className="text-gray-400">@{username}</p>
            </div>
          </div>
          <p className="text-center text-gray-300 mb-6">
            Would you like to connect with {displayName}?
          </p>
          <div className="flex space-x-4">
            <button
              onClick={onReject}
              className="flex-1 py-2 px-4 bg-gray-800 text-white rounded-lg hover:bg-gray-700 transition-colors"
            >
              Decline
            </button>
            <button
              onClick={onAccept}
              className="flex-1 py-2 px-4 bg-cyan-400 text-gray-900 rounded-lg hover:bg-cyan-300 transition-colors"
            >
              Accept
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}