import React, { useState, useEffect, useRef } from 'react';
import { X, Send } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { format } from 'date-fns';
import { Link } from 'react-router-dom';

interface Comment {
  id: string;
  user_id: string;
  post_id: string;
  comment_text: string;
  created_at: string;
  user: {
    username: string;
    display_name: string;
    avatar_url: string | null;
  };
}

interface CommentsModalProps {
  postId: string;
  onCommentAdded?: () => void;
  onClose: () => void;
}

export function CommentsModal({ postId, onCommentAdded, onClose }: CommentsModalProps) {
  const [comments, setComments] = useState<Comment[]>([]);
  const [newComment, setNewComment] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const commentsEndRef = useRef<HTMLDivElement>(null);
  const modalRef = useRef<HTMLDivElement>(null);

  // Handle clicking outside to close
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (modalRef.current && !modalRef.current.contains(event.target as Node)) {
        onClose();
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [onClose]);

  useEffect(() => {
    loadComments();
    // Focus the input field when modal opens
    setTimeout(() => {
      inputRef.current?.focus();
    }, 100);

    const subscription = supabase
      .channel(`comments:${postId}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'interactions',
        filter: `post_id=eq.${postId}`,
      }, handleNewComment)
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, [postId]);

  useEffect(() => {
    scrollToBottom();
  }, [comments]);

  const scrollToBottom = () => {
    commentsEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const handleNewComment = (payload: any) => {
    if (payload.new.type === 'comment') {
      loadComments();
    }
  };

  async function loadComments() {
    try {
      setLoading(true);
      const { data, error: commentsError } = await supabase
        .from('interactions')
        .select(`
          *,
          user:user_id (
            username,
            display_name,
            avatar_url
          )
        `)
        .eq('post_id', postId)
        .eq('type', 'comment')
        .order('created_at', { ascending: true });

      if (commentsError) throw commentsError;
      setComments(data || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load comments');
    } finally {
      setLoading(false);
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newComment.trim()) return;

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      const { error } = await supabase
        .from('interactions')
        .insert({
          user_id: user.id,
          post_id: postId,
          type: 'comment',
          comment_text: newComment.trim()
        });

      if (error) throw error;
      onCommentAdded?.();
      setNewComment('');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to post comment');
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-75 flex items-end sm:items-center justify-center z-[100] p-0 sm:p-4">
      <div 
        ref={modalRef} 
        className="bg-gray-900 w-full sm:w-[480px] sm:rounded-lg sm:max-h-[600px] h-[85vh] sm:h-[80vh] flex flex-col"
      >
        {/* Header */}
        <div className="p-4 border-b border-gray-800 flex justify-between items-center">
          <h2 className="text-xl font-bold">Comments</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-white">
            <X className="w-6 h-6" />
          </button>
        </div>

        {/* Comments List */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4 pb-20 sm:pb-4">
          {loading ? (
            <div className="flex justify-center py-4">
              <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-cyan-400"></div>
            </div>
          ) : comments.length === 0 ? (
            <div className="text-center text-gray-400 py-8">
              <p>No comments yet</p>
              <p className="text-sm mt-1">Be the first to comment!</p>
            </div>
          ) : (
            comments.map((comment) => (
              <div key={comment.id} className="flex space-x-3">
                <Link to={`/profile/${comment.user.username}`}>
                  <img
                    src={comment.user.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(comment.user.display_name)}&background=random`}
                    alt={comment.user.display_name}
                    className="w-8 h-8 rounded-full"
                  />
                </Link>
                <div className="flex-1">
                  <div className="flex items-baseline space-x-2">
                    <Link 
                      to={`/profile/${comment.user.username}`}
                      className="font-semibold hover:text-cyan-400 transition-colors"
                    >
                      {comment.user.display_name}
                    </Link>
                    <span className="text-xs text-gray-400">
                      {format(new Date(comment.created_at), 'MMM d, h:mm a')}
                    </span>
                  </div>
                  <p className="text-gray-200 mt-1">{comment.comment_text}</p>
                </div>
              </div>
            ))
          )}
          <div ref={commentsEndRef} />
        </div>

        {/* Comment Input */}
        <form 
          onSubmit={handleSubmit} 
          className="fixed sm:absolute bottom-0 left-0 right-0 p-4 border-t border-gray-800 bg-gray-900 sm:rounded-b-lg"
        >
          {error && (
            <div className="mb-4 p-3 bg-red-400/10 text-red-400 rounded-lg text-sm">
              {error}
            </div>
          )}
          <div className="flex space-x-2 items-center max-w-lg mx-auto">
            <input
              type="text"
              ref={inputRef}
              value={newComment}
              onChange={(e) => setNewComment(e.target.value)}
              onKeyPress={(e) => e.key === 'Enter' && !e.shiftKey && handleSubmit(e)}
              placeholder="Add a comment..."
              className="flex-1 bg-gray-800 border border-gray-700 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400 appearance-none min-h-[44px]"
            />
            <button
              type="submit"
              disabled={!newComment.trim()}
              className="bg-cyan-400 text-gray-900 p-2 rounded-lg hover:bg-cyan-300 transition-colors disabled:opacity-50 disabled:cursor-not-allowed min-w-[44px] min-h-[44px] flex items-center justify-center"
            >
              <Send className="w-5 h-5" />
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}