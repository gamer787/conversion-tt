import React, { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { ChevronLeft, DollarSign, Clock, Users, Building2, Send } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { format } from 'date-fns';

interface SponsoredContent {
  id: string;
  title: string;
  description: string;
  content_url: string;
  budget: number;
  target_audience: string[];
  status: string;
  views: number;
  start_time: string;
  end_time: string;
  created_at: string;
  user: {
    username: string;
    display_name: string;
    avatar_url: string | null;
  };
}

export default function SponsoredDetails() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [content, setContent] = useState<SponsoredContent | null>(null);
  const [loading, setLoading] = useState(true);
  const [applying, setApplying] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [isEligible, setIsEligible] = useState(false);
  const [hasApplied, setHasApplied] = useState(false);
  const [application, setApplication] = useState({
    portfolio_url: '',
    cover_letter: ''
  });

  useEffect(() => {
    loadContent();
    checkEligibility();
  }, [id]);

  const loadContent = async () => {
    try {
      if (!id) return;
      setLoading(true);

      const { data, error } = await supabase
        .from('sponsored_content')
        .select(`
          *,
          user:user_id (
            username,
            display_name,
            avatar_url
          )
        `)
        .eq('i d', id)
        .single();

      if (error) throw error;
      setContent(data);

      // Check if user has already applied
      const { data: { user } } = await supabase.auth.getUser();
      if (user) {
        const { data: application } = await supabase
          .from('sponsored_content_applications')
          .select('id')
          .eq('content_id', id)
          .eq('applicant_id', user.id)
          .maybeSingle();

        setHasApplied(!!application);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load content');
    } finally {
      setLoading(false);
    }
  };

  const checkEligibility = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        setIsEligible(false);
        return;
      }

      // Get user's profile
      const { data: profile } = await supabase
        .from('profiles')
        .select('account_type')
        .eq('id', user.id)
        .single();

      // If business account, they're not eligible to apply
      if (profile?.account_type === 'business') {
        setIsEligible(false);
        return;
      }

      // Check eligibility criteria
      const [
        { count: linksCount },
        { count: bangersCount },
        { count: vibesCount },
        { count: brandsCount },
        { data: accountAge }
      ] = await Promise.all([
        // Get links count
        supabase
          .from('friend_requests')
          .select('*', { count: 'exact', head: true })
          .eq('status', 'accepted')
          .or(`sender_id.eq.${user.id},receiver_id.eq.${user.id}`),
        
        // Get bangers count
        supabase
          .from('posts')
          .select('*', { count: 'exact', head: true })
          .eq('user_id', user.id)
          .eq('type', 'banger'),
        
        // Get vibes count
        supabase
          .from('posts')
          .select('*', { count: 'exact', head: true })
          .eq('user_id', user.id)
          .eq('type', 'vibe'),
        
        // Get followed business count
        supabase
          .from('follows')
          .select('following_id', { count: 'exact', head: true })
          .eq('follower_id', user.id)
          .eq('profiles.account_type', 'business'),
        
        // Get account creation date
        supabase
          .from('profiles')
          .select('created_at')
          .eq('id', user.id)
          .single()
      ]);

      // Calculate account age in days
      const accountAgeInDays = accountAge?.created_at
        ? Math.floor((Date.now() - new Date(accountAge.created_at).getTime()) / (1000 * 60 * 60 * 24))
        : 0;

      // Check if user has posted in last 30 days
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
      
      const { count: recentPostCount } = await supabase
        .from('posts')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id)
        .gte('created_at', thirtyDaysAgo.toISOString());

      // Check all eligibility criteria
      const isEligible = 
        (linksCount || 0) >= 2000 &&
        (bangersCount || 0) >= 45 &&
        (vibesCount || 0) >= 30 &&
        (brandsCount || 0) >= 15 &&
        accountAgeInDays >= 90 &&
        (recentPostCount || 0) > 0;

      setIsEligible(isEligible);
    } catch (err) {
      console.error('Error checking eligibility:', err);
      setIsEligible(false);
    }
  };

  const handleApply = async () => {
    try {
      setApplying(true);
      setError(null);
      setSuccess(null);

      if (!application.cover_letter.trim()) {
        throw new Error('Please provide a cover letter');
      }

      const { error } = await supabase
        .from('sponsored_content_applications')
        .insert({
          content_id: id,
          portfolio_url: application.portfolio_url,
          cover_letter: application.cover_letter
        });

      if (error) throw error;

      setSuccess('Application submitted successfully!');
      setHasApplied(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to submit application');
    } finally {
      setApplying(false);
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center py-12">
        <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-cyan-400"></div>
      </div>
    );
  }

  if (!content) {
    return (
      <div className="text-center py-12">
        <p className="text-red-400">Content not found</p>
        <button
          onClick={() => navigate('/hub/sponsored')}
          className="mt-4 text-cyan-400 hover:text-cyan-300"
        >
          Back to Sponsored Content
        </button>
      </div>
    );
  }

  return (
    <div className="pb-20 pt-4">
      <div className="flex items-center space-x-3 mb-8">
        <button
          onClick={() => navigate('/hub/sponsored')}
          className="p-2 hover:bg-gray-800 rounded-lg transition-colors"
        >
          <ChevronLeft className="w-6 h-6" />
        </button>
        <h1 className="text-2xl font-bold">Sponsored Content Details</h1>
      </div>

      <div className="space-y-6">
        {/* Header */}
        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="flex items-start justify-between">
            <div className="flex items-start space-x-4">
              <Link to={`/profile/${content.user.username}`}>
                <img
                  src={content.user.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(content.user.display_name)}&background=random`}
                  alt={content.user.display_name}
                  className="w-12 h-12 rounded-full"
                />
              </Link>
              <div>
                <Link 
                  to={`/profile/${content.user.username}`}
                  className="font-semibold hover:text-cyan-400 transition-colors"
                >
                  {content.user.display_name}
                </Link>
                <h2 className="text-2xl font-bold mt-2">{content.title}</h2>
                <div className="flex flex-wrap items-center gap-4 mt-4">
                  <div className="flex items-center text-gray-400">
                    <DollarSign className="w-4 h-4 mr-1" />
                    <span>₹{content.budget.toLocaleString()}</span>
                  </div>
                  <div className="flex items-center text-gray-400">
                    <Clock className="w-4 h-4 mr-1" />
                    <span>
                      {format(new Date(content.start_time), 'MMM d')} -{' '}
                      {format(new Date(content.end_time), 'MMM d')}
                    </span>
                  </div>
                  <div className="flex items-center text-gray-400">
                    <Users className="w-4 h-4 mr-1" />
                    <span>{content.views} views</span>
                  </div>
                </div>
              </div>
            </div>
            <span className={`px-3 py-1 rounded-full text-sm ${
              content.status === 'active'
                ? 'bg-green-400/10 text-green-400'
                : content.status === 'completed'
                ? 'bg-gray-400/10 text-gray-400'
                : content.status === 'cancelled'
                ? 'bg-red-400/10 text-red-400'
                : 'bg-yellow-400/10 text-yellow-400'
            }`}>
              {content.status.charAt(0).toUpperCase() + content.status.slice(1)}
            </span>
          </div>
        </div>

        {/* Content Preview */}
        <div className="bg-gray-900 p-6 rounded-lg">
          <h3 className="text-lg font-semibold mb-4">Content Preview</h3>
          {content.content_url.includes('.mp4') ? (
            <video
              src={content.content_url}
              className="w-full max-h-96 object-contain rounded-lg"
              controls
            />
          ) : (
            <img
              src={content.content_url}
              alt={content.title}
              className="w-full max-h-96 object-contain rounded-lg"
            />
          )}
        </div>

        {/* Description */}
        <div className="bg-gray-900 p-6 rounded-lg">
          <h3 className="text-lg font-semibold mb-4">Description</h3>
          <p className="text-gray-300 whitespace-pre-wrap">{content.description}</p>
        </div>

        {/* Target Audience */}
        {content.target_audience.length > 0 && (
          <div className="bg-gray-900 p-6 rounded-lg">
            <h3 className="text-lg font-semibold mb-4">Target Audience</h3>
            <div className="flex flex-wrap gap-2">
              {content.target_audience.map((tag, index) => (
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

        {/* Application Form */}
        {content.status === 'active' && !hasApplied && (
          <div className="bg-gray-900 p-6 rounded-lg">
            <h3 className="text-lg font-semibold mb-4">Apply for this Opportunity</h3>
            
            {!isEligible ? (
              <div className="bg-yellow-400/10 text-yellow-400 p-4 rounded-lg">
                <h4 className="font-semibold mb-2">Not Eligible</h4>
                <p className="text-sm">
                  To apply for sponsored content opportunities, you need to meet the following criteria:
                </p>
                <ul className="list-disc list-inside mt-2 space-y-1 text-sm">
                  <li>Have 2,000+ accepted friend requests</li>
                  <li>Have posted 45+ bangers</li>
                  <li>Have posted 30+ vibes</li>
                  <li>Follow 15+ business accounts</li>
                  <li>Account age of 90+ days</li>
                  <li>Posted content in the last 30 days</li>
                </ul>
                <Link
                  to="/hub/fund/info"
                  className="inline-block mt-4 text-yellow-400 hover:text-yellow-300"
                >
                  Learn more about eligibility
                </Link>
              </div>
            ) : (
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-1">
                    Portfolio URL (optional)
                  </label>
                  <input
                    type="url"
                    value={application.portfolio_url}
                    onChange={(e) => setApplication(prev => ({ ...prev, portfolio_url: e.target.value }))}
                    className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                    placeholder="https://example.com/portfolio"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-1">
                    Cover Letter
                  </label>
                  <textarea
                    value={application.cover_letter}
                    onChange={(e) => setApplication(prev => ({ ...prev, cover_letter: e.target.value }))}
                    className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400 min-h-[200px]"
                    placeholder="Tell us why you're interested in this opportunity..."
                    required
                  />
                </div>

                {error && (
                  <div className="bg-red-400/10 text-red-400 p-4 rounded-lg">
                    {error}
                  </div>
                )}

                {success && (
                  <div className="bg-green-400/10 text-green-400 p-4 rounded-lg">
                    {success}
                  </div>
                )}

                <button
                  onClick={handleApply}
                  disabled={applying}
                  className="w-full bg-cyan-400 text-gray-900 py-3 rounded-lg font-semibold hover:bg-cyan-300 transition-colors disabled:opacity-50 flex items-center justify-center space-x-2"
                >
                  <Send className="w-5 h-5" />
                  <span>{applying ? 'Submitting...' : 'Submit Application'}</span>
                </button>
              </div>
            )}
          </div>
        )}

        {hasApplied && (
          <div className="bg-green-400/10 border border-green-400 text-green-400 rounded-lg p-4">
            You have already applied for this opportunity
          </div>
        )}

        {content.status !== 'active' && (
          <div className="bg-gray-800 text-gray-400 rounded-lg p-4 text-center">
            This opportunity is no longer accepting applications
          </div>
        )}
      </div>
    </div>
  );
}