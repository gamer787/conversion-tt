import React, { useState, useRef } from 'react';
import { Link } from 'react-router-dom';
import { Heart, MessageCircle, Trash2 } from 'lucide-react';
import { format } from 'date-fns';

interface Post {
  id: string;
  type: 'vibe';
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

interface VibesProps {
  posts: Post[];
  currentUserId: string | null;
  likedPosts: Set<string>;
  onLike: (postId: string) => void;
  onComment: (postId: string) => void;
  onDelete: (post: { id: string; type: 'vibe' }) => void;
  isProfileView?: boolean;
}

export function Vibes({ posts, currentUserId, likedPosts, onLike, onComment, onDelete, isProfileView = false }: VibesProps) {
  const [currentIndex, setCurrentIndex] = useState(0);
  const touchStartY = useRef<number | null>(null);

  const handleTouchStart = (e: React.TouchEvent) => {
    touchStartY.current = e.touches[0].clientY;
  };

  const handleTouchMove = (e: React.TouchEvent) => {
    if (touchStartY.current === null) return;

    const touchEndY = e.touches[0].clientY;
    const deltaY = touchEndY - touchStartY.current;

    if (Math.abs(deltaY) > 50) {
      if (deltaY > 0 && currentIndex > 0) {
        setCurrentIndex(prev => prev - 1);
      } else if (deltaY < 0 && currentIndex < posts.length - 1) {
        setCurrentIndex(prev => prev + 1);
      }
      touchStartY.current = null;
    }
  };

  const handleTouchEnd = () => {
    touchStartY.current = null;
  };

  const handleWheel = (e: React.WheelEvent) => {
    if (e.deltaY > 0 && currentIndex < posts.length - 1) {
      setCurrentIndex(prev => prev + 1);
    } else if (e.deltaY < 0 && currentIndex > 0) {
      setCurrentIndex(prev => prev - 1);
    }
  };

  if (isProfileView) {
    return (
      <div className="grid grid-cols-3 gap-[2px]">
        {posts.map((post) => (
          <div 
            key={post.id} 
            className="relative group aspect-square overflow-hidden"
          >
            <img
              src={post.content_url}
              alt={post.caption}
              className="w-full h-full object-cover"
            />
            {currentUserId === post.user.id && (
              <div className="absolute inset-0 bg-black bg-opacity-50 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                <button
                  onClick={() => onDelete({ id: post.id, type: 'vibe' })}
                  className="p-2 bg-red-500 rounded-full hover:bg-red-600 transition-colors"
                >
                  <Trash2 className="w-5 h-5" />
                </button>
              </div>
            )}
            <div className="absolute bottom-0 left-0 right-0 p-2 bg-gradient-to-t from-black/80 to-transparent opacity-0 group-hover:opacity-100 transition-opacity">
              <div className="flex items-center justify-between text-white">
                <div className="flex items-center space-x-2">
                  <button
                    onClick={() => onLike(post.id)}
                    className={likedPosts.has(post.id) ? 'text-pink-500' : 'hover:text-pink-500'}
                  >
                    <Heart className={`w-5 h-5 ${likedPosts.has(post.id) ? 'fill-current' : ''}`} />
                  </button>
                  <button
                    onClick={() => onComment(post.id)}
                    className="hover:text-purple-500"
                  >
                    <MessageCircle className="w-5 h-5" />
                  </button>
                </div>
                <div className="text-sm">
                  {format(new Date(post.created_at), 'MMM d')}
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>
    );
  }

  // Single post view for feed
  return posts.length === 0 ? (
    <div className="text-center text-gray-400 py-8">No vibes to show</div>
  ) : (
    <div 
      className="h-[calc(100vh-12rem)] overflow-hidden"
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
      onWheel={handleWheel}
    >
      <div
        className="h-full transition-transform duration-300"
        style={{
          transform: `translateY(-${currentIndex * 100}%)`
        }}
      >
        {posts.map((post, index) => (
          <div
            key={post.id}
            className="h-full w-full relative"
          >
            <div className="absolute inset-0 bg-black">
              <img
                src={post.content_url}
                alt={post.caption}
                className="w-full h-full object-contain"
              />
            </div>

            {/* Bottom Info and Actions */}
            <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/90 via-black/50 to-transparent p-4">
              <Link 
                to={`/profile/${post.user.username}`}
                className="flex items-center space-x-3 mb-3"
              >
                <img
                  src={post.user.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(post.user.display_name)}&background=random`}
                  alt={post.user.display_name}
                  className="w-10 h-10 rounded-full"
                />
                <div>
                  <div className="flex items-center space-x-2">
                    <span className="font-semibold text-white">{post.user.display_name}</span>
                    {post.user.badge && (
                      <span className="bg-cyan-400/10 text-cyan-400 px-2 py-0.5 rounded text-sm">
                        {post.user.badge.role}
                      </span>
                    )}
                  </div>
                  <p className="text-sm text-gray-300">
                    {format(new Date(post.created_at), 'MMM d, h:mm a')}
                  </p>
                </div>
              </Link>

              {post.caption && (
                <p className="text-white text-sm mb-4">{post.caption}</p>
              )}

              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-4">
                  <button
                    onClick={() => onLike(post.id)}
                    className={`flex items-center space-x-2 ${
                      likedPosts.has(post.id)
                        ? 'text-pink-500'
                        : 'text-white hover:text-pink-500'
                    }`}
                  >
                    <Heart className={`w-6 h-6 ${likedPosts.has(post.id) ? 'fill-current' : ''}`} />
                    <span>{post.likes_count}</span>
                  </button>
                  <button 
                    onClick={() => onComment(post.id)}
                    className="flex items-center space-x-2 text-white hover:text-purple-500 transition-colors"
                  >
                    <MessageCircle className="w-6 h-6" />
                    <span>{post.comments_count}</span>
                  </button>
                </div>

                {currentUserId === post.user.id && (
                  <button
                    onClick={() => onDelete({ id: post.id, type: 'vibe' })}
                    className="p-2 text-white hover:text-red-500 transition-colors rounded-full hover:bg-white/10"
                  >
                    <Trash2 className="w-6 h-6" />
                  </button>
                )}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

export default Vibes;