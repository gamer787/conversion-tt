import React, { useState, useRef, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { Heart, MessageCircle, Trash2, Volume2, VolumeX } from 'lucide-react';
import { format } from 'date-fns';

interface Post {
  id: string;
  type: 'banger';
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

interface BangersProps {
  posts: Post[];
  currentUserId: string | null;
  likedPosts: Set<string>;
  onLike: (postId: string) => void;
  onComment: (postId: string) => void;
  onDelete: (post: { id: string; type: 'banger' }) => void;
}

export function Bangers({ posts, currentUserId, likedPosts, onLike, onComment, onDelete }: BangersProps) {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [isMuted, setIsMuted] = useState(true);
  const videoRefs = useRef<(HTMLVideoElement | null)[]>([]);

  useEffect(() => {
    // Initialize video refs array
    videoRefs.current = videoRefs.current.slice(0, posts.length);
  }, [posts]);

  useEffect(() => {
    // Pause all videos except the current one
    videoRefs.current.forEach((video, index) => {
      if (video) {
        if (index === currentIndex) {
          video.play().catch(() => {
            // Autoplay might be blocked
          });
        } else {
          video.pause();
        }
      }
    });
  }, [currentIndex]);

  const handleScroll = (e: React.WheelEvent) => {
    if (e.deltaY > 0 && currentIndex < posts.length - 1) {
      setCurrentIndex(prev => prev + 1);
    } else if (e.deltaY < 0 && currentIndex > 0) {
      setCurrentIndex(prev => prev - 1);
    }
  };

  const handleTouchStart = useRef<number | null>(null);

  const handleTouchMove = (e: React.TouchEvent) => {
    if (handleTouchStart.current === null) {
      handleTouchStart.current = e.touches[0].clientY;
      return;
    }

    const touchEnd = e.touches[0].clientY;
    const diff = handleTouchStart.current - touchEnd;

    if (Math.abs(diff) > 50) { // Minimum swipe distance
      if (diff > 0 && currentIndex < posts.length - 1) {
        setCurrentIndex(prev => prev + 1);
      } else if (diff < 0 && currentIndex > 0) {
        setCurrentIndex(prev => prev - 1);
      }
      handleTouchStart.current = null;
    }
  };

  const handleTouchEnd = () => {
    handleTouchStart.current = null;
  };

  return (
    <div 
      className="fixed inset-0 bg-black z-50 overflow-hidden"
      onWheel={handleScroll}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
    >
      <div 
        className="h-full transition-transform duration-300"
        style={{
          transform: `translateY(-${currentIndex * 100}%)`
        }}
      >
        {posts.map((post, index) => (
          <div key={post.id} className="h-full w-full relative">
            <video
              ref={el => videoRefs.current[index] = el}
              src={post.content_url}
              className="absolute inset-0 w-full h-full object-contain bg-black"
              loop
              playsInline
              muted={isMuted}
              autoPlay={index === currentIndex}
            />

            {/* Overlay Content */}
            <div className="absolute inset-0 bg-gradient-to-b from-black/50 via-transparent to-black/50">
              {/* User Info */}
              <div className="absolute bottom-20 left-4 right-12">
                <Link 
                  to={`/profile/${post.user.username}`}
                  className="flex items-center space-x-2 mb-2"
                >
                  <img
                    src={post.user.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(post.user.display_name)}&background=random`}
                    alt={post.user.display_name}
                    className="w-8 h-8 rounded-full"
                  />
                  <span className="font-semibold text-white">{post.user.display_name}</span>
                  {post.user.badge && (
                    <span className="bg-cyan-400/10 text-cyan-400 px-2 py-0.5 rounded text-sm">
                      {post.user.badge.role}
                    </span>
                  )}
                </Link>
                {post.caption && (
                  <p className="text-white text-sm">{post.caption}</p>
                )}
                <p className="text-sm text-gray-300 mt-2">
                  {format(new Date(post.created_at), 'MMM d, h:mm a')}
                </p>
              </div>

              {/* Actions */}
              <div className="absolute right-4 bottom-20 flex flex-col items-center space-y-6">
                <button
                  onClick={() => onLike(post.id)}
                  className="flex flex-col items-center"
                >
                  <div className={`p-2 rounded-full ${
                    likedPosts.has(post.id)
                      ? 'text-pink-500'
                      : 'text-white hover:bg-white/10'
                  }`}>
                    <Heart
                      className={`w-6 h-6 ${likedPosts.has(post.id) ? 'fill-current' : ''}`}
                    />
                  </div>
                  <span className="text-white text-xs">{post.likes_count}</span>
                </button>

                <button
                  onClick={() => onComment(post.id)}
                  className="flex flex-col items-center"
                >
                  <div className="p-2 rounded-full text-white hover:bg-white/10">
                    <MessageCircle className="w-6 h-6" />
                  </div>
                  <span className="text-white text-xs">{post.comments_count}</span>
                </button>

                {currentUserId === post.user.id && (
                  <button
                    onClick={() => onDelete({ id: post.id, type: 'banger' })}
                    className="p-2 text-white hover:text-red-500 hover:bg-white/10 rounded-full"
                  >
                    <Trash2 className="w-6 h-6" />
                  </button>
                )}

                <button
                  onClick={() => setIsMuted(!isMuted)}
                  className="p-2 text-white hover:bg-white/10 rounded-full"
                >
                  {isMuted ? (
                    <VolumeX className="w-6 h-6" />
                  ) : (
                    <Volume2 className="w-6 h-6" />
                  )}
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}