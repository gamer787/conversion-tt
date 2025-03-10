import React, { useState, useEffect } from 'react';
import { ChevronLeft, DollarSign, Users, Film, ImageIcon, Calendar, CheckCircle, XCircle } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';

interface EligibilityStatus {
  linksCount: number;
  bangersCount: number;
  vibesCount: number;
  brandsCount: number;
  accountAge: number;
  isActive: boolean;
}

function CreatorFund() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [eligibility, setEligibility] = useState<EligibilityStatus>({
    linksCount: 0,
    bangersCount: 0,
    vibesCount: 0,
    brandsCount: 0,
    accountAge: 0,
    isActive: false
  });

  useEffect(() => {
    loadEligibility();
  }, []);

  const loadEligibility = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      // Get user's profile and post counts
      const [
        { data: profile },
        { count: bangersCount },
        { count: vibesCount },
        { data: brands }
      ] = await Promise.all([
        // Get profile
        supabase
          .from('profiles')
          .select('created_at')
          .eq('id', user.id)
          .single(),
        
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
        
        // Get brands
        supabase
          .from('follows')
          .select(`
            following_id,
            profiles!follows_following_id_fkey (
              account_type
            )
          `)
          .eq('follower_id', user.id)
          .eq('profiles.account_type', 'business')
      ]);

      if (!profile) return;

      // Calculate account age in days
      const accountAge = Math.floor(
        (new Date().getTime() - new Date(profile.created_at).getTime()) / (1000 * 60 * 60 * 24)
      );

      // Get links count (already returns array)
      const { data: links } = await supabase.rpc('get_profile_links', {
        profile_id: user.id,
        include_badges: false
      });

      // Filter to only count business accounts
      const businessBrands = brands.filter(b => b.profiles?.account_type === 'business');

      // Check if user has been active in the last 30 days
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      const { count: activeCount } = await supabase
        .from('posts')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', user.id)
        .gte('created_at', thirtyDaysAgo.toISOString());

      setEligibility({
        linksCount: links?.length || 0,
        bangersCount: Number(bangersCount) || 0,
        vibesCount: Number(vibesCount) || 0,
        brandsCount: businessBrands.length || 0,
        accountAge,
        isActive: (activeCount || 0) > 0
      });
    } catch (error) {
      console.error('Error loading eligibility:', error);
    } finally {
      setLoading(false);
    }
  };

  const getRequirementStatus = (current: number, required: number) => {
    const percentage = Math.min((current / required) * 100, 100);
    return {
      percentage,
      met: current >= required
    };
  };

  const requirements = {
    links: getRequirementStatus(eligibility.linksCount, 2000),
    bangers: getRequirementStatus(eligibility.bangersCount, 45),
    vibes: getRequirementStatus(eligibility.vibesCount, 30),
    brands: getRequirementStatus(eligibility.brandsCount, 15),
    accountAge: getRequirementStatus(eligibility.accountAge, 90)
  };

  const allRequirementsMet = 
    requirements.links.met &&
    requirements.bangers.met &&
    requirements.vibes.met &&
    requirements.brands.met &&
    requirements.accountAge.met &&
    eligibility.isActive;

  if (loading) {
    return (
      <div className="flex justify-center py-12">
        <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-green-400"></div>
      </div>
    );
  }

  return (
    <div className="pb-20 pt-4">
      <div className="flex items-center space-x-3 mb-8">
        <button
          onClick={() => navigate('/hub')}
          className="p-2 hover:bg-gray-800 rounded-lg transition-colors"
        >
          <ChevronLeft className="w-6 h-6" />
        </button>
        <h1 className="text-2xl font-bold">Creator Fund</h1>
      </div>

      {/* Hero Section */}
      <div className="bg-gradient-to-br from-green-400/20 to-yellow-400/20 p-8 rounded-lg border border-green-400/20 mb-8">
        <div className="flex items-center justify-center mb-6">
          <DollarSign className="w-16 h-16 text-green-400" />
        </div>
        <h2 className="text-2xl font-bold text-center mb-4">Earn from Your Content</h2>
        <p className="text-gray-300 text-center max-w-2xl mx-auto">
          Join our Creator Fund and earn 10% of all profits generated from your content, 
          with plans to increase to 15% in the future. Get rewarded for your creativity 
          and engagement on the platform.
        </p>
      </div>

      {/* Eligibility Status */}
      <div className="bg-gray-900 p-6 rounded-lg mb-8">
        <h3 className="text-lg font-semibold mb-6">Your Eligibility Status</h3>
        
        <div className="space-y-6">
          {/* Links Requirement */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center space-x-2">
                <Users className="w-5 h-5 text-purple-400" />
                <span className="font-medium">Links</span>
              </div>
              <div className="flex items-center space-x-2">
                <span className="text-sm text-gray-400">
                  {eligibility.linksCount} / 2,000
                </span>
                {requirements.links.met ? (
                  <CheckCircle className="w-5 h-5 text-green-400" />
                ) : (
                  <XCircle className="w-5 h-5 text-red-400" />
                )}
              </div>
            </div>
            <div className="h-2 bg-gray-800 rounded-full overflow-hidden">
              <div 
                className="h-full bg-purple-400 transition-all duration-500"
                style={{ width: `${requirements.links.percentage}%` }}
              />
            </div>
          </div>

          {/* Bangers Requirement */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center space-x-2">
                <Film className="w-5 h-5 text-blue-400" />
                <span className="font-medium">Bangers</span>
              </div>
              <div className="flex items-center space-x-2">
                <span className="text-sm text-gray-400">
                  {eligibility.bangersCount} / 45
                </span>
                {requirements.bangers.met ? (
                  <CheckCircle className="w-5 h-5 text-green-400" />
                ) : (
                  <XCircle className="w-5 h-5 text-red-400" />
                )}
              </div>
            </div>
            <div className="h-2 bg-gray-800 rounded-full overflow-hidden">
              <div 
                className="h-full bg-blue-400 transition-all duration-500"
                style={{ width: `${requirements.bangers.percentage}%` }}
              />
            </div>
          </div>

          {/* Vibes Requirement */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center space-x-2">
                <ImageIcon className="w-5 h-5 text-pink-400" />
                <span className="font-medium">Vibes</span>
              </div>
              <div className="flex items-center space-x-2">
                <span className="text-sm text-gray-400">
                  {eligibility.vibesCount} / 30
                </span>
                {requirements.vibes.met ? (
                  <CheckCircle className="w-5 h-5 text-green-400" />
                ) : (
                  <XCircle className="w-5 h-5 text-red-400" />
                )}
              </div>
            </div>
            <div className="h-2 bg-gray-800 rounded-full overflow-hidden">
              <div 
                className="h-full bg-pink-400 transition-all duration-500"
                style={{ width: `${requirements.vibes.percentage}%` }}
              />
            </div>
          </div>

          {/* Account Age Requirement */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center space-x-2">
                <Calendar className="w-5 h-5 text-yellow-400" />
                <span className="font-medium">Account Age</span>
              </div>
              <div className="flex items-center space-x-2">
                <span className="text-sm text-gray-400">
                  {eligibility.accountAge} / 90 days
                </span>
                {requirements.accountAge.met ? (
                  <CheckCircle className="w-5 h-5 text-green-400" />
                ) : (
                  <XCircle className="w-5 h-5 text-red-400" />
                )}
              </div>
            </div>
            <div className="h-2 bg-gray-800 rounded-full overflow-hidden">
              <div 
                className="h-full bg-yellow-400 transition-all duration-500"
                style={{ width: `${requirements.accountAge.percentage}%` }}
              />
            </div>
          </div>

          {/* Activity Status */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center space-x-2">
                <DollarSign className="w-5 h-5 text-green-400" />
                <span className="font-medium">Active User Status</span>
              </div>
              {eligibility.isActive ? (
                <div className="bg-green-400/10 text-green-400 px-3 py-1 rounded-full text-sm">
                  Active
                </div>
              ) : (
                <div className="bg-red-400/10 text-red-400 px-3 py-1 rounded-full text-sm">
                  Inactive
                </div>
              )}
            </div>
            <p className="text-sm text-gray-400">
              {eligibility.isActive 
                ? 'You have posted content in the last 30 days'
                : 'Post content to maintain active status'}
            </p>
          </div>
        </div>

        {/* Overall Status */}
        <div className="mt-8 p-6 bg-gray-800 rounded-lg">
          <div className="flex items-center justify-between">
            <h4 className="font-semibold">Overall Status</h4>
            {allRequirementsMet && eligibility.isActive ? (
              <div className="bg-green-400/10 text-green-400 px-4 py-1 rounded-full">
                Eligible
              </div>
            ) : (
              <div className="bg-yellow-400/10 text-yellow-400 px-4 py-1 rounded-full">
                {eligibility.isActive ? 'Requirements Not Met' : 'Inactive Account'}
              </div>
            )}
          </div>
          <p className="text-sm text-gray-400 mt-2">
            {allRequirementsMet && eligibility.isActive
              ? 'Congratulations! You are eligible to join the Creator Fund.'
              : eligibility.isActive
                ? 'Keep working towards meeting all requirements to join the Creator Fund.'
                : 'Post content in the last 30 days to maintain active status.'}
          </p>
          {allRequirementsMet && eligibility.isActive ? (
            <button className="mt-4 w-full bg-gradient-to-r from-green-400 to-yellow-400 text-gray-900 py-3 rounded-lg font-semibold hover:opacity-90 transition-opacity">
              Join Creator Fund
            </button>
          ) : (
            <div className="mt-4 space-y-4">
              <div className="p-4 bg-gray-900 rounded-lg">
                <h5 className="font-semibold mb-2">Requirements Checklist</h5>
                <ul className="space-y-2 text-sm">
                  <li className="flex items-center space-x-2">
                    {requirements.links.met ? (
                      <CheckCircle className="w-4 h-4 text-green-400" />
                    ) : (
                      <XCircle className="w-4 h-4 text-red-400" />
                    )}
                    <span>2,000 Links ({eligibility.linksCount} current)</span>
                  </li>
                  <li className="flex items-center space-x-2">
                    {requirements.bangers.met ? (
                      <CheckCircle className="w-4 h-4 text-green-400" />
                    ) : (
                      <XCircle className="w-4 h-4 text-red-400" />
                    )}
                    <span>45 Bangers ({eligibility.bangersCount} current)</span>
                  </li>
                  <li className="flex items-center space-x-2">
                    {requirements.vibes.met ? (
                      <CheckCircle className="w-4 h-4 text-green-400" />
                    ) : (
                      <XCircle className="w-4 h-4 text-red-400" />
                    )}
                    <span>30 Vibes ({eligibility.vibesCount} current)</span>
                  </li>
                  <li className="flex items-center space-x-2">
                    {requirements.brands.met ? (
                      <CheckCircle className="w-4 h-4 text-green-400" />
                    ) : (
                      <XCircle className="w-4 h-4 text-red-400" />
                    )}
                    <span>15 Brands ({eligibility.brandsCount} current)</span>
                  </li>
                  <li className="flex items-center space-x-2">
                    {requirements.accountAge.met ? (
                      <CheckCircle className="w-4 h-4 text-green-400" />
                    ) : (
                      <XCircle className="w-4 h-4 text-red-400" />
                    )}
                    <span>90 Days Account Age</span>
                  </li>
                  <li className="flex items-center space-x-2">
                    {eligibility.isActive ? (
                      <CheckCircle className="w-4 h-4 text-green-400" />
                    ) : (
                      <XCircle className="w-4 h-4 text-red-400" />
                    )}
                    <span>Active in Last 30 Days</span>
                  </li>
                </ul>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* How It Works */}
      <div className="bg-gray-900 p-6 rounded-lg mb-8">
        <h3 className="text-lg font-semibold mb-6">How It Works</h3>
        <div className="space-y-6">
          <div className="flex items-start space-x-4">
            <div className="w-8 h-8 bg-green-400 text-gray-900 rounded-full flex items-center justify-center flex-shrink-0 font-bold">
              1
            </div>
            <div>
              <h4 className="font-semibold mb-2">Meet Eligibility Requirements</h4>
              <p className="text-gray-400">
                Build your presence on the platform by growing your network, creating engaging content,
                and maintaining regular activity.
              </p>
            </div>
          </div>

          <div className="flex items-start space-x-4">
            <div className="w-8 h-8 bg-green-400 text-gray-900 rounded-full flex items-center justify-center flex-shrink-0 font-bold">
              2
            </div>
            <div>
              <h4 className="font-semibold mb-2">Join the Fund</h4>
              <p className="text-gray-400">
                Once eligible, join the Creator Fund to start earning from your content and engagement.
                Your earnings are based on views, interactions, and overall impact.
              </p>
            </div>
          </div>

          <div className="flex items-start space-x-4">
            <div className="w-8 h-8 bg-green-400 text-gray-900 rounded-full flex items-center justify-center flex-shrink-0 font-bold">
              3
            </div>
            <div>
              <h4 className="font-semibold mb-2">Get Paid</h4>
              <p className="text-gray-400">
                Receive monthly payments based on your contribution to the platform. Currently, creators
                earn 10% of profits, with plans to increase to 15% in the future.
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Tips for Success */}
      <div className="bg-gray-900 p-6 rounded-lg">
        <h3 className="text-lg font-semibold mb-6">Tips for Success</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="p-4 bg-gray-800 rounded-lg">
            <Users className="w-6 h-6 text-purple-400 mb-3" />
            <h4 className="font-semibold mb-2">Grow Your Network</h4>
            <p className="text-sm text-gray-400">
              Connect with other creators and engage with your audience regularly.
            </p>
          </div>

          <div className="p-4 bg-gray-800 rounded-lg">
            <Film className="w-6 h-6 text-blue-400 mb-3" />
            <h4 className="font-semibold mb-2">Create Quality Content</h4>
            <p className="text-sm text-gray-400">
              Focus on producing engaging bangers and vibes that resonate with your audience.
            </p>
          </div>

          <div className="p-4 bg-gray-800 rounded-lg">
            <Calendar className="w-6 h-6 text-yellow-400 mb-3" />
            <h4 className="font-semibold mb-2">Stay Consistent</h4>
            <p className="text-sm text-gray-400">
              Maintain regular activity and post content consistently to maximize earnings.
            </p>
          </div>

          <div className="p-4 bg-gray-800 rounded-lg">
            <DollarSign className="w-6 h-6 text-green-400 mb-3" />
            <h4 className="font-semibold mb-2">Track Performance</h4>
            <p className="text-sm text-gray-400">
              Monitor your analytics and adjust your strategy to optimize earnings.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

export default CreatorFund;