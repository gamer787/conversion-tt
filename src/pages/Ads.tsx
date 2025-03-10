import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { ChevronLeft, History, AlertCircle } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { CommentsModal } from '../components/CommentsModal';
import { ContentSelector } from '../components/ads/ContentSelector';
import { PricingTiers } from '../components/ads/PricingTiers';
import { ReachEstimator } from '../components/ads/ReachEstimator';
import { PaymentModal } from '../components/ads/PaymentModal';
import { AdCard } from '../components/ads/AdCard';
import { useAdCampaigns } from '../hooks/useAdCampaigns';
import { useAdPayment } from '../hooks/useAdPayment';
import type { Content, PriceTier } from '../types/ads';

function Ads() {
  const navigate = useNavigate();
  const [content, setContent] = useState<Content[]>([]);
  const [selectedContent, setSelectedContent] = useState<Content | null>(null);
  const [priceTiers, setPriceTiers] = useState<PriceTier[]>([]);
  const [selectedTier, setSelectedTier] = useState<PriceTier | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showPaymentModal, setShowPaymentModal] = useState(false);
  const [nearbyUsers, setNearbyUsers] = useState<{ distance: number; user_count: number; }[]>([]);
  const [selectedPost, setSelectedPost] = useState<string | null>(null);
  const [showPreviousAds, setShowPreviousAds] = useState(false);
  const [likedPosts, setLikedPosts] = useState<Set<string>>(new Set());
  const [showConfirmation, setShowConfirmation] = useState<{
    type: 'success' | 'error';
    title: string;
    message: string;
    details: string[];
  } | null>(null);

  const {
    activeCampaigns,
    previousCampaigns,
    loading: campaignsLoading,
    error: campaignsError,
    stopCampaign,
    reloadCampaigns
  } = useAdCampaigns();

  const {
    loading: paymentLoading,
    processPayment
  } = useAdPayment({
    onSuccess: () => {
      setShowConfirmation({
        type: 'success',
        title: 'Campaign Created Successfully!',
        message: 'Your ad campaign is now active and will start showing to users in your selected area.',
        details: [
          `Duration: ${selectedTier?.duration_hours} hours`,
          `Radius: ${selectedTier?.radius_km}km`,
          `Estimated Reach: ${getEstimatedReach(selectedTier?.radius_km || 0).toLocaleString()}+ users`
        ]
      });
      setShowPaymentModal(false);
      reloadCampaigns();
    },
    onError: (error) => {
      setError(error);
      setShowConfirmation({
        type: 'error',
        title: 'Campaign Creation Failed',
        message: error,
        details: []
      });
    }
  });

  useEffect(() => {
    loadContent();
    loadPriceTiers();
    loadNearbyUserCounts();
    loadLikedPosts();
  }, []);

  const loadLikedPosts = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data: likes } = await supabase
        .from('interactions')
        .select('post_id')
        .eq('user_id', user.id)
        .eq('type', 'like');

      setLikedPosts(new Set(likes?.map(like => like.post_id)));
    } catch (error) {
      console.error('Error loading liked posts:', error);
    }
  };

  const loadContent = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data } = await supabase
        .from('posts')
        .select('id, type, content_url, caption, created_at')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false });

      setContent(data || []);
    } catch (error) {
      console.error('Error loading content:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadPriceTiers = async () => {
    try {
      const { data } = await supabase
        .from('ad_price_tiers')
        .select('*')
        .order('duration_hours', { ascending: true })
        .order('radius_km', { ascending: true });

      setPriceTiers(data || []);

      if (data?.length) {
        setSelectedTier(data[0]);
      }
    } catch (error) {
      console.error('Error loading price tiers:', error);
    }
  };

  const loadNearbyUserCounts = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data: profile } = await supabase
        .from('profiles')
        .select('latitude, longitude')
        .eq('id', user.id)
        .single();

      if (!profile?.latitude || !profile?.longitude) return;

      const distances = [5, 25, 50, 100];
      const counts = distances.map(distance => ({
        distance,
        user_count: Math.floor(Math.random() * 1000) + 100 // Estimate for demo
      }));

      setNearbyUsers(counts);
    } catch (error) {
      console.error('Error loading nearby users:', error);
    }
  };

  const getEstimatedReach = (radius: number): number => {
    const nearestCount = nearbyUsers.find(count => count.distance >= radius);
    return nearestCount?.user_count || 0;
  };

  const handleLike = async (postId: string) => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      if (likedPosts.has(postId)) {
        // Unlike
        const { error } = await supabase
          .from('interactions')
          .delete()
          .match({
            user_id: user.id,
            post_id: postId,
            type: 'like'
          });

        if (error) throw error;

        setLikedPosts(prev => {
          const next = new Set(prev);
          next.delete(postId);
          return next;
        });
      } else {
        // Like
        const { error } = await supabase
          .from('interactions')
          .insert({
            user_id: user.id,
            post_id: postId,
            type: 'like'
          });

        if (error) throw error;

        setLikedPosts(prev => new Set([...prev, postId]));
      }
      reloadCampaigns();
    } catch (err) {
      console.error('Error liking post:', err);
    }
  };

  const handlePaymentSuccess = async () => {
    if (!selectedContent || !selectedTier) return;

    try {
      const { data: { user }, error: authError } = await supabase.auth.getUser();
      if (authError) throw authError;
      if (!user) throw new Error('Not authenticated');

      const { data: profile } = await supabase
        .from('profiles')
        .select('display_name')
        .eq('id', user.id)
        .single();

      if (!profile) throw new Error('Profile not found');

      await processPayment(
        {
          duration_hours: selectedTier.duration_hours,
          radius_km: selectedTier.radius_km,
          price: selectedTier.price,
          content_id: selectedContent.id
        },
        {
          name: profile.display_name,
          email: user.email || ''
        }
      );

      // Only clear selected content on success
      if (!error) {
        setSelectedContent(null);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create campaign');
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center py-8">
        <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-cyan-400"></div>
      </div>
    );
  }

  return (
    <div className="pb-20 pt-4">
      <div className="flex items-center space-x-3 mb-6">
        <button
          onClick={() => navigate('/hub')}
          className="p-2 hover:bg-gray-800 rounded-lg transition-colors"
        >
          <ChevronLeft className="w-6 h-6" />
        </button>
        <div>
          <h1 className="text-2xl font-bold">Advertising</h1>
          <p className="text-sm text-gray-400 mt-1">Manage your ad campaigns</p>
         </div>
        <button
          onClick={() => setShowPreviousAds(!showPreviousAds)}
          className="ml-auto flex items-center space-x-2 bg-gray-800 text-white px-4 py-2 rounded-lg hover:bg-gray-700 transition-colors"
        >
          <History className="w-5 h-5" />
          <span>{showPreviousAds ? 'Current Ads' : 'Previous Ads'}</span>
        </button>
      </div>

      {/* Active Campaigns */}
      {!showPreviousAds && activeCampaigns.length > 0 && (
        <div className="mb-8">
          <h2 className="text-lg font-semibold mb-4">Active Campaigns</h2>
          <div className="space-y-4">
            {activeCampaigns.map((campaign) => (
              <AdCard
                key={campaign.id}
                campaign={campaign}
                onLike={handleLike}
                onComment={(postId) => setSelectedPost(postId)}
                onStop={stopCampaign}
                likedPosts={likedPosts}
              />
            ))}
          </div>
        </div>
      )}

      {/* Previous Campaigns */}
      {showPreviousAds && (
        <div className="mb-8">
          <h2 className="text-lg font-semibold mb-4">Previous Campaigns</h2>
          <div className="space-y-4">
            {previousCampaigns.map((campaign) => (
              <AdCard
                key={campaign.id}
                campaign={campaign}
                onLike={handleLike}
                onComment={(postId) => setSelectedPost(postId)}
                onStop={stopCampaign}
                likedPosts={likedPosts}
              />
            ))}
          </div>
        </div>
      )}

      {/* Create New Campaign */}
      <div className="bg-gradient-to-br from-gray-900 to-gray-800 rounded-lg p-6 border border-gray-800">
        <h2 className="text-lg font-semibold mb-4">Create New Campaign</h2>
        
        {!selectedContent ? (
          <ContentSelector
            content={content}
            selectedContent={selectedContent}
            onSelectContent={setSelectedContent}
          />
        ) : (
          <div>
            {/* Selected Content Preview */}
            <div className="flex items-start space-x-4 mb-6">
              <div className="w-24 h-24 bg-gray-800 rounded-lg overflow-hidden">
                {selectedContent.type === 'vibe' ? (
                  <img
                    src={selectedContent.content_url}
                    alt={selectedContent.caption}
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <video
                    src={selectedContent.content_url}
                    className="w-full h-full object-cover"
                  />
                )}
              </div>
              <div className="flex-1">
                <div className="flex items-center justify-between">
                  <h3 className="font-semibold">Selected Content</h3>
                  <button
                    onClick={() => setSelectedContent(null)}
                    className="text-sm text-gray-400 hover:text-white"
                  >
                    Change
                  </button>
                </div>
                <p className="text-sm text-gray-400 mt-1">{selectedContent.caption}</p>
              </div>
            </div>

            {/* Campaign Settings */}
            <div className="space-y-6">
              <PricingTiers
                priceTiers={priceTiers}
                selectedTier={selectedTier}
                onSelectTier={(tier) => setSelectedTier(tier)}
              />

              <ReachEstimator
                estimatedReach={getEstimatedReach(selectedTier?.radius_km || 0)}
                duration={selectedTier?.duration_hours || 0}
                radius={selectedTier?.radius_km || 0}
                price={selectedTier?.price || 0}
              />

              <button
                onClick={() => setShowPaymentModal(true)}
                className="w-full bg-gradient-to-r from-cyan-400 to-purple-400 text-gray-900 py-4 rounded-lg font-semibold hover:from-cyan-300 hover:to-purple-300 transition-colors shadow-lg shadow-cyan-400/10"
              >
                Create Campaign
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Modals */}
      {showPaymentModal && selectedTier && (
        <PaymentModal
          onConfirm={handlePaymentSuccess}
          onCancel={() => setShowPaymentModal(false)}
          loading={paymentLoading}
          error={error}
          success={null}
          duration={selectedTier.duration_hours}
          radius={selectedTier.radius_km}
          estimatedReach={getEstimatedReach(selectedTier.radius_km)}
          price={selectedTier.price}
        />
      )}

      {selectedPost && (
        <CommentsModal
          postId={selectedPost}
          onCommentAdded={() => reloadCampaigns()}
          onClose={() => setSelectedPost(null)}
        />
      )}

      {showConfirmation && (
        <div className="fixed inset-0 bg-black/90 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-gradient-to-br from-gray-900 to-gray-800 rounded-lg w-full max-w-md p-6 border border-gray-800 relative">
            <div className={`flex items-center space-x-2 ${
              showConfirmation.type === 'success' ? 'text-green-400' : 'text-red-400'
            } mb-4`}>
              <AlertCircle className="w-6 h-6" />
              <h3 className="text-lg font-semibold">{showConfirmation.title}</h3>
            </div>
            
            <p className="text-gray-300 mb-4">{showConfirmation.message}</p>
            
            {showConfirmation.details.length > 0 && (
              <div className="bg-gray-800 p-4 rounded-lg space-y-2 mb-6">
                {showConfirmation.details.map((detail, index) => (
                  <div key={index} className="flex items-center space-x-2">
                    <div className="w-2 h-2 rounded-full bg-cyan-400"></div>
                    <span className="text-gray-300">{detail}</span>
                  </div>
                ))}
              </div>
            )}
            
            <div className="flex justify-end">
              <button
                onClick={() => setShowConfirmation(null)}
                className={`px-6 py-2 rounded-lg font-semibold transition-colors ${
                  showConfirmation.type === 'success'
                    ? 'bg-green-400 text-gray-900 hover:bg-green-300'
                    : 'bg-gray-800 text-white hover:bg-gray-700'
                }`}
              >
                {showConfirmation.type === 'success' ? 'Done' : 'Try Again'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default Ads;