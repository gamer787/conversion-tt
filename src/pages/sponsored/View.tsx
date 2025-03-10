import React, { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { ChevronLeft, Plus, Building2, Clock, DollarSign, Users, Eye, AlertTriangle } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { format } from 'date-fns';

interface SponsoredContent {
  id: string;
  title: string;
  description: string;
  content_url: string;
  budget: number;
  target_audience: string[];
  status: 'draft' | 'pending' | 'active' | 'completed' | 'cancelled';
  views: number;
  start_time: string;
  end_time: string;
  created_at: string;
  user: {
    username: string;
    display_name: string;
    avatar_url: string | null;
  };
  applications_count: number;
}

export default function ViewSponsored() {
  const navigate = useNavigate();
  const [content, setContent] = useState<SponsoredContent[]>([]);
  const [isBusinessAccount, setIsBusinessAccount] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filterStatus, setFilterStatus] = useState<'all' | 'active' | 'completed'>('active');
  const [contentToDelete, setContentToDelete] = useState<SponsoredContent | null>(null);

  useEffect(() => {
    checkAccountType();
    loadContent();
  }, [filterStatus]);

  const checkAccountType = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data: profile } = await supabase
        .from('profiles')
        .select('account_type')
        .eq('id', user.id)
        .single();

      setIsBusinessAccount(profile?.account_type === 'business');
    } catch (error) {
      console.error('Error checking account type:', error);
    }
  };

  const loadContent = async () => {
    try {
      setLoading(true);
      const { data: { user }, error: authError } = await supabase.auth.getUser();
      if (authError) throw authError;
      if (!user) return;

      // Get user's profile to check account type
      const { data: profile } = await supabase
        .from('profiles')
        .select('account_type')
        .eq('id', user.id)
        .single();

      let query = supabase
        .from('sponsored_content')
        .select(`
          *,
          user:user_id (
            username,
            display_name,
            avatar_url
          ),
          applications:sponsored_content_applications(count)
        `);

      // Business accounts see their own content, users see active content
      if (profile?.account_type === 'business') {
        query = query.eq('user_id', user.id);
      } else {
        query = query.eq('status', 'active');
      }

      if (filterStatus !== 'all') {
        query = query.eq('status', filterStatus);
      }

      const { data, error } = await query.order('created_at', { ascending: false });

      if (error) throw error;

      setContent(data?.map(item => ({
        ...item,
        applications_count: item.applications?.[0]?.count || 0
      })) || []);

      // Update business account status
      setIsBusinessAccount(profile?.account_type === 'business');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load content');
    } finally {
      setLoading(false);
    }
  };

  const handleStatusChange = async (contentId: string, newStatus: SponsoredContent['status']) => {
    try {
      const { error } = await supabase
        .from('sponsored_content')
        .update({ status: newStatus })
        .eq('id', contentId);

      if (error) throw error;

      setContent(prev => prev.map(item =>
        item.id === contentId ? { ...item, status: newStatus } : item
      ));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update status');
    }
  };

  const handleDelete = async () => {
    if (!contentToDelete) return;
    
    try {
      const { error } = await supabase
        .from('sponsored_content')
        .delete()
        .eq('id', contentToDelete.id);

      if (error) throw error;

      setContent(prev => prev.filter(item => item.id !== contentToDelete.id));
      setContentToDelete(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete content');
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center py-12">
        <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-cyan-400"></div>
      </div>
    );
  }

  return (
    <div className="pb-20 pt-4">
      <div className="flex items-center justify-between mb-8">
        <div className="flex items-center space-x-3">
          <button
            onClick={() => navigate('/hub')}
            className="p-2 hover:bg-gray-800 rounded-lg transition-colors"
          >
            <ChevronLeft className="w-6 h-6" />
          </button>
          <div>
            <h1 className="text-2xl font-bold">Sponsored Content</h1>
            <p className="text-sm text-gray-400 mt-1">
              {isBusinessAccount ? 'Manage your sponsored content' : 'Browse sponsored opportunities'}
            </p>
          </div>
        </div>
        {isBusinessAccount && (
          <Link
            to="/hub/sponsored/create"
            className="bg-cyan-400 text-gray-900 px-4 py-2 rounded-lg font-semibold hover:bg-cyan-300 transition-colors flex items-center space-x-2"
          >
            <Plus className="w-5 h-5" />
            <span>Create New</span>
          </Link>
        )}
      </div>

      {/* Filters */}
      <div className="flex space-x-2 mb-6">
        <button
          onClick={() => setFilterStatus('all')}
          className={`px-4 py-2 rounded-lg ${
            filterStatus === 'all'
              ? 'bg-cyan-400 text-gray-900'
              : 'bg-gray-800 text-gray-400 hover:bg-gray-700'
          }`}
        >
          All
        </button>
        <button
          onClick={() => setFilterStatus('active')}
          className={`px-4 py-2 rounded-lg ${
            filterStatus === 'active'
              ? 'bg-cyan-400 text-gray-900'
              : 'bg-gray-800 text-gray-400 hover:bg-gray-700'
          }`}
        >
          Active
        </button>
        <button
          onClick={() => setFilterStatus('completed')}
          className={`px-4 py-2 rounded-lg ${
            filterStatus === 'completed'
              ? 'bg-cyan-400 text-gray-900'
              : 'bg-gray-800 text-gray-400 hover:bg-gray-700'
          }`}
        >
          Completed
        </button>
      </div>

      {content.length === 0 ? (
        <div className="text-center py-12 bg-gray-900 rounded-lg">
          <Building2 className="w-12 h-12 text-gray-500 mx-auto mb-4" />
          <h2 className="text-xl font-semibold mb-2">No content found</h2>
          <p className="text-gray-400">
            {isBusinessAccount
              ? 'Create your first sponsored content opportunity'
              : 'Check back later for new opportunities'}
          </p>
        </div>
      ) : (
        <div className="space-y-6">
          {content.map((item) => (
            <div
              key={item.id}
              className="bg-gray-900 rounded-lg overflow-hidden"
            >
              <div className="p-6">
                <div className="flex items-start justify-between">
                  <div className="flex items-start space-x-4">
                    <Link to={`/profile/${item.user.username}`}>
                      <img
                        src={item.user.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(item.user.display_name)}&background=random`}
                        alt={item.user.display_name}
                        className="w-12 h-12 rounded-full"
                      />
                    </Link>
                    <div>
                      <Link 
                        to={`/profile/${item.user.username}`}
                        className="font-semibold hover:text-cyan-400 transition-colors"
                      >
                        {item.user.display_name}
                      </Link>
                      <h2 className="text-xl font-semibold mt-2">{item.title}</h2>
                      <p className="text-gray-400 mt-2">{item.description}</p>
                      <div className="flex flex-wrap items-center gap-4 mt-4">
                        <div className="flex items-center text-gray-400">
                          <DollarSign className="w-4 h-4 mr-1" />
                          <span>₹{item.budget.toLocaleString()}</span>
                        </div>
                        <div className="flex items-center text-gray-400">
                          <Clock className="w-4 h-4 mr-1" />
                          <span>
                            {format(new Date(item.start_time), 'MMM d')} -{' '}
                            {format(new Date(item.end_time), 'MMM d')}
                          </span>
                        </div>
                        <div className="flex items-center text-gray-400">
                          <Eye className="w-4 h-4 mr-1" />
                          <span>{item.views} views</span>
                        </div>
                        {isBusinessAccount && (
                          <div className="flex items-center text-gray-400">
                            <Users className="w-4 h-4 mr-1" />
                            <span>{item.applications_count} applications</span>
                          </div>
                        )}
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center space-x-2">
                    <span className={`px-3 py-1 rounded-full text-sm ${
                      item.status === 'active'
                        ? 'bg-green-400/10 text-green-400'
                        : item.status === 'completed'
                        ? 'bg-gray-400/10 text-gray-400'
                        : item.status === 'cancelled'
                        ? 'bg-red-400/10 text-red-400'
                        : 'bg-yellow-400/10 text-yellow-400'
                    }`}>
                      {item.status.charAt(0).toUpperCase() + item.status.slice(1)}
                    </span>
                  </div>
                </div>

                {/* Preview */}
                <div className="mt-4">
                  {item.content_url.includes('.mp4') ? (
                    <video
                      src={item.content_url}
                      className="w-full max-h-96 object-contain rounded-lg"
                      controls
                    />
                  ) : (
                    <img
                      src={item.content_url}
                      alt={item.title}
                      className="w-full max-h-96 object-contain rounded-lg"
                    />
                  )}
                </div>

                {/* Target Audience */}
                {item.target_audience.length > 0 && (
                  <div className="mt-4">
                    <h3 className="text-sm font-medium text-gray-400 mb-2">Target Audience</h3>
                    <div className="flex flex-wrap gap-2">
                      {item.target_audience.map((tag, index) => (
                        <span
                          key={index}
                          className="px-3 py-1 bg-gray-800 rounded-full text-sm text-gray-300"
                        >
                          {tag}
                        </span>
                      ))}
                    </div>
                  </div>
                )}

                {/* Actions */}
                <div className="mt-6 flex space-x-4">
                  {isBusinessAccount ? (
                    <>
                      <Link
                        to={`/hub/sponsored/${item.id}/applications`}
                        className="flex-1 bg-cyan-400 text-gray-900 py-2 rounded-lg font-semibold hover:bg-cyan-300 transition-colors text-center"
                      >
                        View Applications
                      </Link>
                      <button
                        onClick={() => handleStatusChange(item.id, item.status === 'active' ? 'completed' : 'active')}
                        className={`flex-1 py-2 rounded-lg font-semibold transition-colors ${
                          item.status === 'active'
                            ? 'bg-red-500 text-white hover:bg-red-600'
                            : 'bg-green-500 text-white hover:bg-green-600'
                        }`}
                      >
                        {item.status === 'active' ? 'Complete' : 'Reactivate'}
                      </button>
                    </>
                  ) : (
                    <Link
                      to={`/hub/sponsored/${item.id}`}
                      className="flex-1 bg-cyan-400 text-gray-900 py-2 rounded-lg font-semibold hover:bg-cyan-300 transition-colors text-center"
                    >
                      View Details
                    </Link>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {contentToDelete && (
        <div className="fixed inset-0 bg-black/75 flex items-center justify-center z-50 p-4">
          <div className="bg-gray-900 rounded-lg p-6 max-w-md w-full">
            <div className="flex items-center space-x-3 text-red-500 mb-4">
              <AlertTriangle className="w-6 h-6" />
              <h3 className="text-xl font-bold">Delete Content</h3>
            </div>
            <p className="text-gray-300 mb-4">
              Are you sure you want to delete this sponsored content? This action cannot be undone.
            </p>
            <div className="bg-gray-800 p-4 rounded-lg mb-6">
              <h4 className="font-semibold">{contentToDelete.title}</h4>
              <p className="text-gray-400 mt-1">{contentToDelete.description}</p>
            </div>
            <div className="flex space-x-4">
              <button
                onClick={() => setContentToDelete(null)}
                className="flex-1 bg-gray-800 text-white px-4 py-2 rounded-lg hover:bg-gray-700 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleDelete}
                className="flex-1 bg-red-500 text-white px-4 py-2 rounded-lg hover:bg-red-600 transition-colors"
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}