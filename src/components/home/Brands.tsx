import React from 'react';
import { Link } from 'react-router-dom';
import { Heart, MessageCircle, Building2 } from 'lucide-react';
import { format } from 'date-fns';

interface VisibleAd {
  campaign_id: string;
  user_id: string;
  content_id: string;
  distance: number;
  content: {
    id: string;
    type: 'vibe' | 'banger';
    content_url: string;
    caption: string;
    created_at: string;
    user: {
      username: string;
      display_name: string;
      avatar_url: string | null;
      badge?: {
        role: string;
      };
    };
    likes_count: number;
    comments_count: number;
  };
}

interface BrandsProps {
  ads: VisibleAd[];
  likedPosts: Set<string>;
  onLike: (postId: string) => void;
  onComment: (postId: string) => void;
}

export function Brands({ ads, likedPosts, onLike, onComment }: BrandsProps) {
  return (
    <div className="space-y-6">
      {ads.map((ad) => (
        <div key={`ad-${ad.campaign_id}`} className="bg-gray-900 rounded-lg overflow-hidden">
          {/* Post Header */}
          <div className="px-4 py-3 flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <Link to={`/profile/${ad.content.user.username}`}>
                <img
                  src={ad.content.user.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(ad.content.user.display_name)}&background=random`}
                  alt={ad.content.user.display_name}
                  className="w-9 h-9 rounded-full"
                />
              </Link>
              <div>
                <Link 
                  to={`/profile/${ad.content.user.username}`}
                  className="font-semibold hover:text-cyan-400 transition-colors flex items-center space-x-2"
                >
                  <span>{ad.content.user.display_name}</span>
                  {ad.content.user.badge && (
                    <span className="inline-block bg-cyan-400/10 text-cyan-400 px-3 py-1 rounded-full text-sm font-medium">
                      {ad.content.user.badge.role}
                    </span>
                  )}
                </Link>
                <div className="flex items-center space-x-2">
                  <p className="text-sm text-gray-400">
                    {format(new Date(ad.content?.created_at || new Date()), 'MMM d, h:mm a')}
                  </p>
                  <span className="text-xs text-cyan-400 bg-cyan-400/10 px-2 py-0.5 rounded">
                    Promoted
                  </span>
                </div>
              </div>
            </div>
          </div>

          {/* Post Content */}
          {ad.content?.type === 'vibe' ? (
            <img
              src={ad.content?.content_url}
              alt={ad.content?.caption}
              className="w-full aspect-square object-cover"
            />
          ) : (
            <div className="relative w-full aspect-[9/16] bg-black">
              <video
                src={ad.content?.content_url}
                controls
                className="absolute inset-0 w-full h-full object-contain"
              />
            </div>
          )}

          {/* Post Actions */}
          <div className="px-4 py-3">
            <div className="flex items-center space-x-4 mb-2">
              <button
                onClick={() => ad.content?.id && onLike(ad.content.id)}
                className={`flex items-center space-x-1 transition-colors ${
                  ad.content?.id && likedPosts.has(ad.content.id)
                    ? 'text-pink-500'
                    : 'text-gray-400 hover:text-pink-500'
                }`}
              >
                <Heart
                  className={`w-6 h-6 ${ad.content?.id && likedPosts.has(ad.content.id) ? 'fill-current' : ''}`}
                />
                <span>{ad.content?.likes_count || 0}</span>
              </button>
              <button 
                onClick={() => ad.content?.id && onComment(ad.content.id)}
                className="flex items-center space-x-1 text-gray-400 hover:text-purple-500 transition-colors"
              >
                <MessageCircle className="w-6 h-6" />
                <span>{ad.content?.comments_count || 0}</span>
              </button>
            </div>
            {ad.content?.caption && (
              <p className="text-sm text-gray-200">{ad.content.caption}</p>
            )}
          </div>
        </div>
      ))}
    </div>
  );
}