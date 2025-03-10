import React from 'react';
import { Link } from 'react-router-dom';
import { Heart, MessageCircle, Trash2 } from 'lucide-react';
import { format } from 'date-fns';

interface Post {
  id: string;
  type: 'vibe' | 'banger';
  content_url: string;
  caption: string;
  created_at: string;
  likes_count: number;
  comments_count: number;
  user: {
    id: string;
    username: string;
    display_name: string;
    avatar_url: string | null;
    badge?: {
      role: string;
    };
  };
}

interface AllProps {
  posts: Post[];
  currentUserId: string | null;
  likedPosts: Set<string>;
  onLike: (postId: string) => void;
  onComment: (postId: string) => void;
  onDelete: (post: { id: string; type: 'vibe' | 'banger' }) => void;
}

export function All({ posts, currentUserId, likedPosts, onLike, onComment, onDelete }: AllProps) {
  return (
    <div className="space-y-6">
      {posts.map((post) => (
        <div key={`post-${post.id}`} className="bg-gray-900 rounded-lg overflow-hidden">
          {/* Post Content */}
          {post.type === 'vibe' ? (
            <img
              src={post.content_url}
              alt={post.caption}
              className="w-full aspect-square object-contain bg-black"
            />
          ) : (
            <div className="relative w-full aspect-[9/16] bg-black">
              <video
                src={post.content_url}
                controls
                className="absolute inset-0 w-full h-full object-contain"
              />
            </div>
          )}

          {/* User Info and Actions */}
          <div className="p-4">
            <div className="flex items-center justify-between mb-4">
              <Link 
                to={`/profile/${post.user.username}`}
                className="flex items-center space-x-3"
              >
                <img
                  src={post.user.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(post.user.display_name)}&background=random`}
                  alt={post.user.display_name}
                  className="w-10 h-10 rounded-full"
                />
                <div>
                  <div className="flex items-center space-x-2">
                    <span className="font-semibold">{post.user.display_name}</span>
                    {post.user.badge && (
                      <span className="bg-cyan-400/10 text-cyan-400 px-2 py-0.5 rounded text-sm">
                        {post.user.badge.role}
                      </span>
                    )}
                  </div>
                  <p className="text-sm text-gray-400">
                    {format(new Date(post.created_at), 'MMM d, h:mm a')}
                  </p>
                </div>
              </Link>
              
              {currentUserId === post.user.id && (
                <button
                  onClick={() => onDelete({ id: post.id, type: post.type })}
                  className="p-2 text-gray-400 hover:text-red-500 transition-colors rounded-full hover:bg-gray-800"
                >
                  <Trash2 className="w-5 h-5" />
                </button>
              )}
            </div>
            
            {post.caption && (
              <p className="text-gray-200 mb-4">{post.caption}</p>
            )}

            <div className="flex items-center space-x-4">
              <button
                onClick={() => onLike(post.id)}
                className={`flex items-center space-x-2 ${
                  likedPosts.has(post.id)
                    ? 'text-pink-500'
                    : 'text-gray-400 hover:text-pink-500'
                }`}
              >
                <Heart className={`w-6 h-6 ${likedPosts.has(post.id) ? 'fill-current' : ''}`} />
                <span>{post.likes_count}</span>
              </button>
              <button 
                onClick={() => onComment(post.id)}
                className="flex items-center space-x-2 text-gray-400 hover:text-purple-500 transition-colors"
              >
                <MessageCircle className="w-6 h-6" />
                <span>{post.comments_count}</span>
              </button>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}