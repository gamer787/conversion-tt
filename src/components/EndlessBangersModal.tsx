import React, { useState, useRef, useEffect } from 'react';
import { X, Heart, MessageCircle, User } from 'lucide-react';
import { Link } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { format } from 'date-fns';

interface Banger {
  id: string;
  content_url: string;
  caption: string;
  created_at: string;
  likes_count: number;
  comments_count: number;
  user: {
    username: string;
    display_name: string;
    avatar_url: string | null;
  };
}

interface EndlessBangersModalProps {
  onClose: () => void;
}

export function EndlessBangersModal({ onClose }: EndlessBangersModalProps) {
  const [bangers, setBangers] = useState<Banger[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [likedBangers, setLikedBangers] = useState<Set<string>>(new Set());
  const containerRef = useRef<HTMLDivElement>(null);
  const touchStartY = useRef<number | null>(null);
  const lastLoadedPage = useRef(0);
  const hasMoreBangers = useRef(true);

  useEffect(() => {
    loadBangers();
    loadLikedBangers();
  }, []);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      } else if (e.key === 'ArrowUp' && currentIndex > 0) {
        setCurrentIndex(prev => prev - 1);
      } else if (e.key === 'ArrowDown' && currentIndex < bangers.length - 1) {
        setCurrentIndex(prev => prev + 1);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [currentIndex, onClose]);

  async function loadLikedBangers() {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data: likes } = await supabase
        .from('interactions')
        .select('post_id')
        .eq('user_id', user.id)
        .eq('type', 'like');

      setLikedBangers(new Set(likes?.map(like => like.post_id)));
    } catch (error) {
      console.error('Error loading liked bangers:', error);
    }
  }

  async function loadBangers() {
    try {
      setLoading(true);
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      const PAGE_SIZE = 10;
      const { data, error } = await supabase
        .from('posts')
        .select(`
          *,
          user:user_id (
            username,
            display_name,
            avatar_url
          )
        `)
        .eq('type', 'banger')
        .order('created_at', { ascending: false })
        .range(lastLoadedPage.current * PAGE_SIZE, (lastLoadedPage.current + 1) * PAGE_SIZE - 1);

      if (error) throw error;

      if (data.length < PAGE_SIZE) {
        hasMoreBangers.current = false;
      }

      setBangers(prev => [...prev, ...data]);
      lastLoadedPage.current += 1;
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load bangers');
    } finally {
      setLoading(false);
    }
  }

  const handleLike = async (bangerId: string) => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      if (likedBangers.has(bangerId)) {
        // Unlike
        const { error } = await supabase
          .from('interactions')
          .delete()
          .match({
            user_id: user.id,
            post_id: bangerId,
            type: 'like'
          });

        if (error) throw error;

        setLikedBangers(prev => {
          const next = new Set(prev);
          next.delete(bangerId);
          return next;
        });
        setBangers(prev => prev.map(banger => 
          banger.id === bangerId 
            ? { ...banger, likes_count: Math.max(0, banger.likes_count - 1) }
            : banger
        ));
      } else {
        // Like
        const { error } = await supabase
          .from('interactions')
          .insert({
            user_id: user.id,
            post_id: bangerId,
            type: 'like'
          });

        if (error) throw error;

        setLikedBangers(prev => new Set([...prev, bangerId]));
        setBangers(prev => prev.map(banger => 
          banger.id === bangerId 
            ? { ...banger, likes_count: banger.likes_count + 1 }
            : banger
        ));
      }
    } catch (err) {
      console.error('Error liking banger:', err);
    }
  };

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
      } else if (deltaY < 0 && currentIndex < bangers.length - 1) {
        setCurrentIndex(prev => prev + 1);
        
        // Load more bangers if we're near the end
        if (currentIndex >= bangers.length - 3 && !loading && hasMoreBangers.current) {
          loadBangers();
        }
      }
      touchStartY.current = null;
    }
  };

  const handleTouchEnd = () => {
    touchStartY.current = null;
  };

  const handleWheel = (e: React.WheelEvent) => {
    if (e.deltaY > 0 && currentIndex < bangers.length - 1) {
      setCurrentIndex(prev => prev + 1);
      
      // Load more bangers if we're near the end
      if (currentIndex >= bangers.length - 3 && !loading && hasMoreBangers.current) {
        loadBangers();
      }
    } else if (e.deltaY < 0 && currentIndex > 0) {
      setCurrentIndex(prev => prev - 1);
    }
  };

  if (loading && bangers.length === 0) {
    return (
      <div className="fixed inset-0 bg-black flex items-center justify-center z-[100]">
        <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-cyan-400"></div>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 bg-black z-[100]">
      <button
        onClick={onClose}
        className="absolute top-4 right-4 z-10 text-white p-2 rounded-full hover:bg-white/10 transition-colors"
      >
        <X className="w-6 h-6" />
      </button>

      <div
        ref={containerRef}
        className="h-full overflow-hidden"
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
          {bangers.map((banger, index) => (
            <div
              key={banger.id}
              className="h-full w-full relative"
            >
              <video
                src={banger.content_url}
                className="absolute inset-0 w-full h-full object-contain bg-black"
                autoPlay={index === currentIndex}
                loop
                playsInline
                muted={index !== currentIndex}
                controls={false}
              />

              {/* Overlay Content */}
              <div className="absolute inset-0 bg-gradient-to-b from-black/50 via-transparent to-black/50">
                {/* User Info */}
                <div className="absolute bottom-20 left-4 right-12">
                  <Link 
                    to={`/profile/${banger.user.username}`}
                    className="flex items-center space-x-2 mb-2"
                    onClick={onClose}
                  >
                    <img
                      src={banger.user.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(banger.user.display_name)}&background=random`}
                      alt={banger.user.display_name}
                      className="w-8 h-8 rounded-full"
                    />
                    <span className="font-semibold text-white">{banger.user.display_name}</span>
                  </Link>
                  {banger.caption && (
                    <p className="text-white text-sm">{banger.caption}</p>
                  )}
                </div>

                {/* Actions */}
                <div className="absolute right-4 bottom-20 flex flex-col items-center space-y-6">
                  <button
                    onClick={() => handleLike(banger.id)}
                    className="flex flex-col items-center"
                  >
                    <div className={`p-2 rounded-full ${
                      likedBangers.has(banger.id)
                        ? 'text-pink-500'
                        : 'text-white hover:bg-white/10'
                    }`}>
                      <Heart
                        className={`w-6 h-6 ${likedBangers.has(banger.id) ? 'fill-current' : ''}`}
                      />
                    </div>
                    <span className="text-white text-xs">{banger.likes_count}</span>
                  </button>

                  <Link
                    to={`/profile/${banger.user.username}`}
                    className="flex flex-col items-center"
                    onClick={onClose}
                  >
                    <div className="p-2 rounded-full text-white hover:bg-white/10">
                      <User className="w-6 h-6" />
                    </div>
                    <span className="text-white text-xs">Profile</span>
                  </Link>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}