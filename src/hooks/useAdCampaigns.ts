import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import type { AdCampaign } from '../types/ads';

export function useAdCampaigns() {
  const [activeCampaigns, setActiveCampaigns] = useState<AdCampaign[]>([]);
  const [previousCampaigns, setPreviousCampaigns] = useState<AdCampaign[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadCampaigns();
    const interval = setInterval(loadCampaigns, 30000);
    return () => clearInterval(interval);
  }, []);

  const loadCampaigns = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      // Get campaign data with user info and interaction counts
      const { data: campaigns } = await supabase
        .from('ad_campaigns')
        .select(`
          *,
          user:user_id (
            username,
            display_name,
            avatar_url,
            account_type
          ),
          content:content_id (
            id,
            type,
            content_url,
            caption
          )
        `)
        .eq('user_id', user.id)
        .order('created_at', { ascending: false });

      if (!campaigns) return;

      // Get interaction counts for each campaign
      const { data: interactions } = await supabase
        .from('interactions')
        .select('post_id, type')
        .in('post_id', campaigns.map(c => c.content_id));

      // Calculate likes and comments counts
      const interactionCounts = new Map();
      interactions?.forEach(interaction => {
        const counts = interactionCounts.get(interaction.post_id) || { likes: 0, comments: 0 };
        if (interaction.type === 'like') counts.likes++;
        if (interaction.type === 'comment') counts.comments++;
        interactionCounts.set(interaction.post_id, counts);
      });

      // Merge all data and split into active and previous campaigns
      const campaignsWithCounts = campaigns.map(campaign => ({
        ...campaign,
        likes_count: interactionCounts.get(campaign.content_id)?.likes || 0,
        comments_count: interactionCounts.get(campaign.content_id)?.comments || 0
      }));

      setActiveCampaigns(
        campaignsWithCounts.filter(c => c.status === 'active')
      );
      setPreviousCampaigns(
        campaignsWithCounts.filter(c => c.status === 'completed')
      );
    } catch (error) {
      console.error('Error loading campaigns:', error);
      setError(error instanceof Error ? error.message : 'Failed to load campaigns');
    } finally {
      setLoading(false);
    }
  };

  const stopCampaign = async (campaignId: string) => {
    try {
      const { error } = await supabase
        .from('ad_campaigns')
        .update({ status: 'completed' })
        .eq('id', campaignId);
      
      if (error) throw error;
      
      // Update local state
      setActiveCampaigns(prev => prev.filter(c => c.id !== campaignId));
      loadCampaigns(); // Reload to get updated lists
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to stop campaign');
    }
  };

  return {
    activeCampaigns,
    previousCampaigns,
    loading,
    error,
    stopCampaign,
    reloadCampaigns: loadCampaigns
  };
}