import React from 'react'; 
import { Link, useNavigate } from 'react-router-dom';
import { Megaphone, Briefcase, Building2, PlusCircle, Users, TrendingUp, Settings, AlertCircle, Shield, BadgeCheck, PlayCircle, DollarSign } from 'lucide-react';
import { supabase } from '../lib/supabase';

function Hub() {
  const navigate = useNavigate();
  const [isBusinessAccount, setIsBusinessAccount] = React.useState(false);

  React.useEffect(() => {
    checkAccountType();
  }, []);

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

  return (
    <div className="pb-20 pt-4">
      <h1 className="text-2xl font-bold mb-6">Central Hub</h1>

      <div className="grid grid-cols-2 gap-4">
        {/* Ads Management */}
        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="flex flex-col items-center text-center">
            <div className="bg-cyan-400/10 p-4 rounded-full mb-4">
              <Megaphone className="w-8 h-8 text-cyan-400" />
            </div>
            <h3 className="font-semibold mb-2">Advertising</h3>
            <p className="text-sm text-gray-400 mb-4">Create and manage your ad campaigns</p>
            <Link
              to="/ads"
              className="bg-cyan-400 text-gray-900 px-4 py-2 rounded-lg font-medium hover:bg-cyan-300 transition-colors w-full"
            >
              Run Ads
            </Link>
          </div>
        </div>

        {/* Buy Badge */}
        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="flex flex-col items-center text-center">
            <div className="bg-cyan-400/10 p-4 rounded-full mb-4">
              <BadgeCheck className="w-8 h-8 text-cyan-400" />
            </div>
            <h3 className="font-semibold mb-2">Verification Badge</h3>
            <p className="text-sm text-gray-400 mb-4">Get verified and stand out from the crowd</p>
            <div className="space-y-2 w-full">
              <button
                onClick={() => navigate('/hub/badge/selection')}
                className="bg-cyan-400 text-gray-900 px-4 py-2 rounded-lg font-medium hover:bg-cyan-300 transition-colors w-full block"
              >
                Buy Badge
              </button>
              <Link
                to="/hub/badge/info"
                className="bg-gray-800 text-gray-200 px-4 py-2 rounded-lg font-medium hover:bg-gray-700 transition-colors w-full block"
              >
                Learn More
              </Link>
            </div>
          </div>
        </div>

        {/* Job Listings - Only show post/manage for business accounts */}
        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="flex flex-col items-center text-center">
            <div className="bg-cyan-400/10 p-4 rounded-full mb-4">
              <Briefcase className="w-8 h-8 text-cyan-400" />
            </div>
            <h3 className="font-semibold mb-2">Job Listings</h3>
            <p className="text-sm text-gray-400 mb-4">
              {isBusinessAccount 
                ? "Post and manage job opportunities" 
                : "View and apply for job opportunities"}
            </p>
            <div className="space-y-2 w-full">
              {isBusinessAccount ? (
                <>
                  <Link
                    to="/hub/jobs/create"
                    className="bg-cyan-400 text-gray-900 px-4 py-2 rounded-lg font-medium hover:bg-cyan-300 transition-colors w-full block text-center"
                  >
                    Post Job
                  </Link>
                  <Link
                    to="/hub/jobs"
                    className="bg-gray-800 text-gray-200 px-4 py-2 rounded-lg font-medium hover:bg-gray-700 transition-colors w-full block text-center"
                  >
                    Manage Listings
                  </Link>
                </>
              ) : (
                <>
                  <Link
                    to="/hub/jobs"
                    className="bg-cyan-400 text-gray-900 px-4 py-2 rounded-lg font-medium hover:bg-cyan-300 transition-colors w-full block text-center"
                  >
                    View Listings
                  </Link>
                  <Link
                    to="/hub/jobs/applications"
                    className="bg-gray-800 text-gray-200 px-4 py-2 rounded-lg font-medium hover:bg-gray-700 transition-colors w-full block text-center"
                  >
                    My Applications
                  </Link>
                </>
              )}
              <Link
                to="/hub/jobs/info"
                className="bg-gray-800/50 text-gray-400 px-4 py-2 rounded-lg font-medium hover:bg-gray-800 transition-colors w-full block text-center"
              >
                Learn More
              </Link>
            </div>
          </div>
        </div>

        {/* Business Profile */}
        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="flex flex-col items-center text-center">
            <div className="bg-cyan-400/10 p-4 rounded-full mb-4">
              <Building2 className="w-8 h-8 text-cyan-400" />
            </div>
            <h3 className="font-semibold mb-2">Profile Settings</h3>
            <p className="text-sm text-gray-400 mb-4">Customize your profile settings</p>
            <Link
              to="/hub/profile"
              className="bg-gray-800 text-gray-200 px-4 py-2 rounded-lg font-medium hover:bg-gray-700 transition-colors w-full"
            >
              Edit Profile
            </Link>
          </div>
        </div>

        {/* Sponsored Content */}
        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="flex flex-col items-center text-center">
            <div className="bg-purple-400/10 p-4 rounded-full mb-4">
              <PlayCircle className="w-8 h-8 text-purple-400" />
            </div>
            <h3 className="font-semibold mb-2">Sponsored Content</h3>
            <p className="text-sm text-gray-400 mb-4">
              {isBusinessAccount 
                ? 'Create engaging sponsored content and reach your target audience'
                : 'Find sponsored content opportunities'}
            </p>
            <div className="space-y-2 w-full">
              {isBusinessAccount ? (
                <>
                  <Link
                    to="/hub/sponsored/create"
                    className="bg-purple-400 text-gray-900 px-4 py-2 rounded-lg font-medium hover:bg-purple-300 transition-colors w-full block text-center"
                  >
                    Create Content
                  </Link>
                  <Link
                    to="/hub/sponsored/analytics"
                    className="bg-gray-800 text-gray-200 px-4 py-2 rounded-lg font-medium hover:bg-gray-700 transition-colors w-full block text-center"
                  >
                    View Analytics
                  </Link>
                </>
              ) : (
                <Link
                  to="/hub/sponsored"
                  className="bg-purple-400 text-gray-900 px-4 py-2 rounded-lg font-medium hover:bg-purple-300 transition-colors w-full block text-center"
                >
                  View Offers
                </Link>
              )}
            </div>
          </div>
        </div>

        {/* Creator Fund */}
        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="flex flex-col items-center text-center">
            <div className="bg-green-400/10 p-4 rounded-full mb-4">
              <DollarSign className="w-8 h-8 text-green-400" />
            </div>
            <h3 className="font-semibold mb-2">Creator Fund</h3>
            <p className="text-sm text-gray-400 mb-4">Earn money from your content and engagement</p>
            <div className="space-y-2 w-full">
              <Link
                to="/hub/fund/info"
                className="bg-green-400 text-gray-900 px-4 py-2 rounded-lg font-medium hover:bg-green-300 transition-colors w-full block text-center"
              >
                Enroll Now
              </Link>
            </div>
          </div>
        </div>

        {/* Analytics */}
        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="flex flex-col items-center text-center">
            <div className="bg-cyan-400/10 p-4 rounded-full mb-4">
              <TrendingUp className="w-8 h-8 text-cyan-400" />
            </div>
            <h3 className="font-semibold mb-2">Analytics</h3>
            <p className="text-sm text-gray-400 mb-4">Track your business metrics</p>
            <Link
              to="/hub/analytics"
              className="bg-gray-800 text-gray-200 px-4 py-2 rounded-lg font-medium hover:bg-gray-700 transition-colors w-full"
            >
              View Stats
            </Link>
          </div>
        </div>
      </div>

      {/* Settings Section */}
      <div className="mt-4">
        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <div className="bg-cyan-400/10 p-4 rounded-full">
                <Settings className="w-8 h-8 text-cyan-400" />
              </div>
              <div>
                <h3 className="font-semibold">Account Settings</h3>
                <p className="text-sm text-gray-400">Manage your account preferences</p>
              </div>
            </div>
            <Link
              to="/settings"
              className="bg-gray-800 text-gray-200 px-6 py-2 rounded-lg font-medium hover:bg-gray-700 transition-colors"
            >
              Settings
            </Link>
          </div>
        </div>
      </div>

      {/* Pro Features Banner */}
      <div className="mt-8 p-6 bg-gradient-to-br from-purple-400/20 via-yellow-400/20 to-green-400/20 rounded-lg border border-purple-400/20">
        <div className="flex items-start space-x-4">
          <div className="bg-cyan-400/10 p-3 rounded-full">
            <PlusCircle className="w-6 h-6 text-cyan-400" />
          </div>
          <div>
            <h3 className="text-lg font-semibold text-purple-400 mb-2">Unlock Your Full Potential</h3>
            <p className="text-gray-300 leading-relaxed mb-4">
              Upgrade to access premium features, join the Creator Fund, and maximize your earnings potential.
            </p>
            <button className="bg-gradient-to-r from-purple-400 via-yellow-400 to-green-400 text-gray-900 px-6 py-2 rounded-lg font-semibold hover:opacity-90 transition-opacity">
              Learn More
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

export default Hub;