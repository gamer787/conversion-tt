import React, { useState } from 'react';
import { ChevronLeft, Building2, Code, Stethoscope, Wallet, GraduationCap, Target, Film, Wrench, Scale, Music, CheckCircle, BadgeCheck } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { handleBadgePayment } from '../lib/payments';

interface BadgeCategory {
  name: string;
  roles: string[];
  color: string;
}

const BADGE_CATEGORIES: BadgeCategory[] = [
  {
    name: 'VIP',
    roles: ['VIP'],
    color: 'from-yellow-400 to-amber-400'
  },
  {
    name: 'Tech & Geeky',
    roles: ['CodeWizard', 'CyberNinja', 'PixelPioneer', 'AI Overlord', 'QuantumQuirk'],
    color: 'from-emerald-400 to-cyan-400'
  },
  {
    name: 'Adventure & Travel',
    roles: ['NomadSoul', 'WildWanderer', 'TrailblazerX', 'SkyRider', 'OceanDrifter'],
    color: 'from-blue-400 to-green-400'
  },
  {
    name: 'Foodie & Fun',
    roles: ['SnackMaster', 'CaffeineQueen', 'SpicyMango', 'SugarRush', 'MidnightMuncher'],
    color: 'from-orange-400 to-red-400'
  },
  {
    name: 'Fashion & Aesthetic',
    roles: ['ChicVibes', 'StreetStyleKing', 'RetroFlare', 'GlamStorm', 'DripGod'],
    color: 'from-pink-400 to-purple-400'
  },
  {
    name: 'Music & Arts',
    roles: ['MelodyMaverick', 'BeatJunkie', 'InkSlinger', 'SynthSorcerer', 'CanvasDreamer'],
    color: 'from-violet-400 to-indigo-400'
  },
  {
    name: 'Mysterious & Cool',
    roles: ['ShadowStriker', 'LunarPhantom', 'MidnightEcho', 'FrostByte', 'SilentStorm'],
    color: 'from-gray-400 to-slate-400'
  },
  {
    name: 'Business & Corporate',
    roles: ['CEO', 'CFO', 'COO', 'CMO', 'HR Manager', 'Business Analyst'],
    color: 'from-blue-400 to-cyan-400'
  },
  {
    name: 'Technology & IT',
    roles: ['Software Engineer', 'Data Scientist', 'Cybersecurity Analyst', 'DevOps Engineer', 'UI/UX Designer', 'AI/ML Engineer'],
    color: 'from-purple-400 to-pink-400'
  },
  {
    name: 'Healthcare',
    roles: ['Doctor', 'Nurse', 'Pharmacist', 'Medical Researcher', 'Radiologist', 'Physiotherapist'],
    color: 'from-red-400 to-pink-400'
  },
  {
    name: 'Finance & Banking',
    roles: ['Investment Banker', 'Financial Analyst', 'Risk Manager', 'Accountant', 'Wealth Manager', 'Loan Officer'],
    color: 'from-green-400 to-emerald-400'
  },
  {
    name: 'Education',
    roles: ['Teacher', 'Professor', 'Principal', 'Academic Counselor', 'Educational Technologist', 'Curriculum Developer'],
    color: 'from-yellow-400 to-orange-400'
  },
  {
    name: 'Marketing & Advertising',
    roles: ['Digital Marketer', 'SEO Specialist', 'Content Strategist', 'Brand Manager', 'Social Media Manager', 'Public Relations Specialist'],
    color: 'from-pink-400 to-rose-400'
  },
  {
    name: 'Media & Entertainment',
    roles: ['Journalist', 'Film Director', 'Scriptwriter', 'Video Editor', 'Music Producer', 'Actor'],
    color: 'from-indigo-400 to-purple-400'
  },
  {
    name: 'Manufacturing & Engineering',
    roles: ['Mechanical Engineer', 'Civil Engineer', 'Electrical Engineer', 'Quality Control Specialist', 'Production Manager', 'Industrial Designer'],
    color: 'from-orange-400 to-amber-400'
  },
  {
    name: 'Legal',
    roles: ['Lawyer', 'Judge', 'Paralegal', 'Legal Consultant', 'Corporate Counsel', 'Compliance Officer'],
    color: 'from-slate-400 to-gray-400'
  },
  {
    name: 'Music & Creative Arts',
    roles: ['Singer', 'Musician', 'Songwriter', 'Composer', 'Music Producer', 'Sound Engineer', 'DJ', 'Music Director', 'Talent Manager'],
    color: 'from-violet-400 to-fuchsia-400'
  },
  {
    name: 'Miscellaneous',
    roles: [
      'MemeKing',
      'TrendSetter',
      'VibeMaster',
      'PartyStarter',
      'DreamWeaver',
      'StarChild',
      'CosmicExplorer',
      'ZenMaster',
      'LegendaryBeing'
    ],
    color: 'from-teal-400 to-cyan-400'
  }
];

function BadgeSelection() {
  const navigate = useNavigate();
  const [selectedCategory, setSelectedCategory] = useState<BadgeCategory | null>(null);
  const [selectedRole, setSelectedRole] = useState<string | null>(null);
  const [profile, setProfile] = useState<any>(null);
  const [loading, setLoading] = useState(false);
  const [activeBadge, setActiveBadge] = useState<{
    category: string;
    role: string;
    days_remaining: number;
    subscription_id: string;
    display_name: string;
    username: string;
    avatar_url: string | null;
  } | null>(null);
  const [showCancelConfirm, setShowCancelConfirm] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  // Load user profile
  React.useEffect(() => {
    const loadProfile = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (user) {
        // Get profile and active badge
        const [{ data: profile }, { data: badge }] = await Promise.all([
          supabase
          .from('profiles')
          .select('*')
          .eq('id', user.id),
          supabase
          .rpc('get_active_badge', { target_user_id: user.id })
        ]);

        if (profile?.[0]) {
          setProfile(profile[0]);
        }
        if (badge?.[0]) {
          setActiveBadge(badge[0]);
        }
      }
    };
    loadProfile();
  }, []);

  const handlePurchase = async () => {
    if (!selectedRole || !selectedCategory) return;
    
    setLoading(true);
    setError(null);
    setSuccess(null);

    try {
      const { data: { user }, error: authError } = await supabase.auth.getUser();
      if (authError) throw authError;
      if (!user) throw new Error('Not authenticated');

      // Get user profile and check for active badge
      const [{ data: profile }, { data: activeBadge }] = await Promise.all([
        supabase
        .from('profiles')
        .select('display_name')
        .eq('id', user.id),
        supabase
        .rpc('get_active_badge', { target_user_id: user.id })
      ]);

      if (!profile) throw new Error('Profile not found');
      if (activeBadge?.[0]) throw new Error('You already have an active badge');

      const price = selectedCategory.name === 'VIP' ? 297 : 99;
      
      const { success, error, subscription } = await handleBadgePayment(
        {
          category: selectedCategory.name,
          role: selectedRole,
          price: price
        },
        {
          name: profile[0].display_name,
          email: user.email || ''
        }
      );

      if (!success || error) throw error;
      
      setSuccess('Payment successful! Your badge is now active.');
      
      // Refresh active badge data
      const { data: newBadge } = await supabase
        .rpc('get_active_badge', { target_user_id: user.id });
      
      if (newBadge?.[0]) {
        setActiveBadge(newBadge[0]);
      }
      
      // Clear selection
      setSelectedCategory(null);
      setSelectedRole(null);
      
      navigate('/hub');
    } catch (error) {
      console.error('Error purchasing badge:', error);
      setError(error instanceof Error ? error.message : 'Failed to activate badge. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleCancelBadge = async () => {
    if (!activeBadge) return;
    
    setLoading(true);
    setError(null);
    setSuccess(null);

    try {
      const { error } = await supabase
        .from('badge_subscriptions')
        .update({ cancelled_at: new Date().toISOString() })
        .eq('id', activeBadge.subscription_id);

      if (error) throw error;

      // Update local state
      setActiveBadge(null);
      setShowCancelConfirm(false);
      setSuccess('Badge cancelled successfully. The badge will remain active until its expiry date.');
    } catch (error) {
      console.error('Error cancelling badge:', error);
      setError(error instanceof Error ? error.message : 'Failed to cancel badge. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="pb-20 pt-4">
      <div className="flex items-center space-x-3 mb-8">
        <button
          onClick={() => navigate('/hub')}
          className="p-2 hover:bg-gray-800 rounded-lg transition-colors"
        >
          <ChevronLeft className="w-6 h-6" />
        </button>
        <h1 className="text-2xl font-bold">Select Your Badge</h1>
      </div>

      {/* Active Badge Section */}
      {activeBadge && (
        <div className="mb-8 bg-gradient-to-br from-cyan-400/20 to-purple-400/20 p-6 rounded-lg border border-cyan-400/20">
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-4">
                <div className="bg-cyan-400/10 p-3 rounded-full">
                  <img
                    src={activeBadge.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(activeBadge.display_name)}&background=random`}
                    alt={activeBadge.display_name}
                    className="w-12 h-12 rounded-full"
                  />
                </div>
                <div>
                  <h3 className="font-semibold text-lg text-cyan-400">{activeBadge.display_name}</h3>
                  <p className="text-gray-300">@{activeBadge.username}</p>
                  <div className="mt-1 text-sm bg-cyan-400/10 text-cyan-400 px-2 py-0.5 rounded inline-block">
                    {activeBadge.role}
                  </div>
                  <p className="text-sm text-gray-400">Category: {activeBadge.category}</p>
                </div>
              </div>
              <div className="text-right">
                <div className="text-lg font-bold text-cyan-400">{activeBadge.days_remaining} days</div>
                <p className="text-sm text-gray-400">remaining</p>
              </div>
            </div>
            <button
              onClick={() => setShowCancelConfirm(true)}
              className="w-full bg-red-500/10 text-red-500 py-2 rounded-lg font-medium hover:bg-red-500/20 transition-colors"
            >
              Cancel Badge
            </button>
          </div>
        </div>
      )}

      {/* Cancel Confirmation Modal */}
      {showCancelConfirm && (
        <div className="fixed inset-0 bg-black/75 flex items-center justify-center z-50 p-4">
          <div className="bg-gray-900 rounded-lg p-6 max-w-md w-full">
            <h3 className="text-xl font-bold text-red-500 mb-4">Cancel Badge</h3>
            <p className="text-gray-300 mb-4">
              Are you sure you want to cancel your badge? Please note:
            </p>
            <ul className="list-disc list-inside text-gray-400 space-y-2 mb-6">
              <li>This action cannot be undone</li>
              <li>The badge will remain active until its expiry date</li>
              <li>No refunds will be issued for the remaining time</li>
              <li>You can purchase a new badge after the current one expires</li>
            </ul>
            <div className="flex space-x-4">
              <button
                onClick={() => setShowCancelConfirm(false)}
                className="flex-1 bg-gray-800 text-white px-4 py-2 rounded-lg hover:bg-gray-700 transition-colors"
              >
                Keep Badge
              </button>
              <button
                onClick={handleCancelBadge}
                disabled={loading}
                className="flex-1 bg-red-500 text-white px-4 py-2 rounded-lg hover:bg-red-600 transition-colors disabled:opacity-50"
              >
                {loading ? 'Cancelling...' : 'Cancel Badge'}
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Categories Grid */}
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
          {BADGE_CATEGORIES.map((category) => (
            <button
              key={category.name}
              onClick={() => {
                setSelectedCategory(category);
                setSelectedRole(null);
              }}
              className={`p-6 rounded-lg text-center transition-all transform hover:scale-105 ${
                selectedCategory?.name === category.name
                  ? 'bg-gradient-to-br ' + category.color + ' text-gray-900 shadow-lg'
                  : 'bg-gray-900 hover:bg-gray-800 border border-gray-800'
              }`}
            >
              <div className="flex flex-col items-center justify-center">
                <div className={`w-16 h-16 rounded-full mb-4 flex items-center justify-center ${
                  selectedCategory?.name === category.name
                    ? 'bg-white/20'
                    : 'bg-gray-800/50'
                }`}>
                  {/* Icon based on category */}
                  {category.name === 'Business & Corporate' && <Building2 className="w-8 h-8" />}
                  {category.name === 'Technology & IT' && <Code className="w-8 h-8" />}
                  {category.name === 'Healthcare' && <Stethoscope className="w-8 h-8" />}
                  {category.name === 'Finance & Banking' && <Wallet className="w-8 h-8" />}
                  {category.name === 'Education' && <GraduationCap className="w-8 h-8" />}
                  {category.name === 'Marketing & Advertising' && <Target className="w-8 h-8" />}
                  {category.name === 'Media & Entertainment' && <Film className="w-8 h-8" />}
                  {category.name === 'Manufacturing & Engineering' && <Wrench className="w-8 h-8" />}
                  {category.name === 'Legal' && <Scale className="w-8 h-8" />}
                  {category.name === 'Music & Creative Arts' && <Music className="w-8 h-8" />}
                </div>
                <h3 className="font-semibold mb-2">{category.name}</h3>
                <p className="text-sm opacity-75">
                  {category.roles.length} roles
                </p>
                {selectedCategory?.name === category.name && (
                  <div className="mt-2 text-xs font-medium bg-white/20 px-3 py-1 rounded-full">
                    Selected
                  </div>
                )}
              </div>
            </button>
          ))}
        </div>

        {/* Roles and Preview Section */}
        {selectedCategory && (
          <div className="space-y-6">
            <div className="bg-gray-900 p-6 rounded-lg border border-gray-800">
              <h2 className="text-lg font-semibold mb-4">Choose Your Role in {selectedCategory.name}</h2>
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                  {selectedCategory.roles.map((role) => (
                    <button
                      key={role}
                      onClick={() => setSelectedRole(role)}
                      className={`p-4 rounded-lg text-sm transition-all transform hover:scale-105 ${
                        selectedRole === role
                          ? 'bg-gradient-to-br ' + selectedCategory.color + ' text-gray-900 shadow-lg relative'
                          : 'bg-gray-800 hover:bg-gray-700 border border-gray-700'
                      }`}
                    >
                      <span>{role}</span>
                      {selectedRole === role && (
                        <CheckCircle className="w-4 h-4 absolute top-2 right-2" />
                      )}
                    </button>
                  ))}
              </div>
            </div>

            {/* Badge Preview */}
            {selectedRole && profile && (
              <div className="bg-gray-900 p-6 rounded-lg border border-gray-800">
                    <h3 className="text-lg font-semibold mb-4">Badge Preview</h3>
                    <div className="bg-gradient-to-br from-gray-800 to-gray-900 p-6 rounded-lg shadow-xl border border-gray-700">
                      <div className="flex items-center space-x-4">
                        <div className={`relative rounded-full overflow-hidden ring-4 ring-offset-2 ring-offset-gray-900 ${
                          selectedRole ? 'ring-gradient-' + selectedCategory.color.split(' ')[2] : 'ring-gray-700'
                        }`}>
                          <div className="w-20 h-20">
                            <img
                              src={profile.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(profile.display_name)}&background=random`}
                              alt={profile.display_name}
                              className="w-full h-full rounded-full object-cover"
                              width={80}
                              height={80}
                            />
                          </div>
                        </div>
                        <div>
                          <div className="font-semibold text-lg">{profile.display_name}</div>
                          <div className={`text-sm bg-gradient-to-br ${selectedCategory.color} text-gray-900 px-3 py-1.5 rounded-full inline-block mt-2 font-medium shadow-lg`}>
                            {selectedRole}
                          </div>
                        </div>
                      </div>
                    </div>

                    <button
                      onClick={handlePurchase}
                      disabled={loading || activeBadge}
                      className={`w-full mt-6 bg-gradient-to-br from-cyan-400 to-purple-400 text-gray-900 py-4 rounded-lg font-semibold hover:from-cyan-300 hover:to-purple-300 transition-all transform hover:scale-105 disabled:opacity-50 shadow-lg relative flex items-center justify-center ${
                        activeBadge ? 'opacity-50 cursor-not-allowed' : ''
                      }`}
                    >
                      {loading ? (
                        <>
                          <div className="w-5 h-5 border-2 border-gray-900 border-t-transparent rounded-full animate-spin mr-2" />
                          Processing...
                        </>
                      ) : (
                        activeBadge ? (
                          <>You already have an active badge</>
                        ) : (
                          <>Activate Badge for ₹{selectedCategory.name === 'VIP' ? '297' : '99'}/month</>
                        )
                      )}
                    </button>
                    {activeBadge && (
                      <p className="text-sm text-gray-400 text-center mt-2">
                        You can purchase a new badge after your current badge expires
                      </p>
                    )}
                    {error && (
                      <div className="mt-4 p-3 bg-red-400/10 border border-red-400/20 text-red-400 rounded-lg text-sm">
                        {error}
                      </div>
                    )}
                    {success && (
                      <div className="mt-4 p-3 bg-green-400/10 border border-green-400/20 text-green-400 rounded-lg text-sm">
                        {success}
                      </div>
                    )}
              </div>
            )}
          </div>
        )}
        
        {!selectedCategory && (
          <div className="bg-gray-900 p-6 rounded-lg border border-gray-800 flex items-center justify-center text-gray-400">
            <p>Select a category to view available roles</p>
          </div>
        )}
      </div>
    </div>
  );
}

export default BadgeSelection;