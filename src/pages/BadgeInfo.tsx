import React from 'react';
import { ChevronLeft, BadgeCheck, Zap, Users, Globe, Sparkles, Shield, Rocket, Target, Palette } from 'lucide-react';
import { useNavigate, Link } from 'react-router-dom';

function BadgeInfo() {
  const navigate = useNavigate();

  return (
    <div className="pb-20 pt-4">
      <div className="flex items-center space-x-3 mb-8">
        <button
          onClick={() => navigate('/hub')}
          className="p-2 hover:bg-gray-800 rounded-lg transition-colors"
        >
          <ChevronLeft className="w-6 h-6" />
        </button>
        <h1 className="text-2xl font-bold">About Badges</h1>
      </div>

      {/* Hero Section */}
      <div className="bg-gradient-to-br from-cyan-400/20 to-purple-400/20 p-8 rounded-lg border border-cyan-400/20 mb-8">
        <div className="flex items-center justify-center mb-6">
          <BadgeCheck className="w-16 h-16 text-cyan-400" />
        </div>
        <h2 className="text-2xl font-bold text-center mb-4">Express Your Identity</h2>
        <p className="text-gray-300 text-center max-w-2xl mx-auto">
          Badges in ZappaLink are not verification marks - they're a way to showcase your role, expertise, 
          and creative identity in the community. Stand out and connect with others who share your interests.
        </p>
      </div>

      {/* Benefits Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="bg-cyan-400/10 p-3 rounded-full w-12 h-12 flex items-center justify-center mb-4">
            <Zap className="w-6 h-6 text-cyan-400" />
          </div>
          <h3 className="text-lg font-semibold mb-2">Enhanced Visibility</h3>
          <p className="text-gray-400">
            Your badge appears prominently on your profile and posts, making your content more noticeable 
            in the community feed.
          </p>
        </div>

        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="bg-cyan-400/10 p-3 rounded-full w-12 h-12 flex items-center justify-center mb-4">
            <Users className="w-6 h-6 text-cyan-400" />
          </div>
          <h3 className="text-lg font-semibold mb-2">Community Recognition</h3>
          <p className="text-gray-400">
            Display your professional role or creative pursuit, making it easier for others to identify 
            and connect with you.
          </p>
        </div>

        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="bg-cyan-400/10 p-3 rounded-full w-12 h-12 flex items-center justify-center mb-4">
            <Globe className="w-6 h-6 text-cyan-400" />
          </div>
          <h3 className="text-lg font-semibold mb-2">Network Building</h3>
          <p className="text-gray-400">
            Find and connect with others in your field or industry. Badges make it easier to build 
            meaningful professional relationships.
          </p>
        </div>

        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="bg-cyan-400/10 p-3 rounded-full w-12 h-12 flex items-center justify-center mb-4">
            <Sparkles className="w-6 h-6 text-cyan-400" />
          </div>
          <h3 className="text-lg font-semibold mb-2">Creative Expression</h3>
          <p className="text-gray-400">
            Choose from a variety of badges that best represent your role, allowing you to express 
            your professional identity creatively.
          </p>
        </div>
      </div>

      {/* Additional Benefits */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="bg-cyan-400/10 p-3 rounded-full w-12 h-12 flex items-center justify-center mb-4">
            <Rocket className="w-6 h-6 text-cyan-400" />
          </div>
          <h3 className="text-lg font-semibold mb-2">Career Growth</h3>
          <p className="text-gray-400">
            Showcase your professional journey and connect with opportunities in your field. Badges help 
            highlight your expertise to potential collaborators.
          </p>
        </div>

        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="bg-cyan-400/10 p-3 rounded-full w-12 h-12 flex items-center justify-center mb-4">
            <Target className="w-6 h-6 text-cyan-400" />
          </div>
          <h3 className="text-lg font-semibold mb-2">Targeted Networking</h3>
          <p className="text-gray-400">
            Find and connect with peers in your specific field. Badges make it easier to identify and 
            engage with professionals sharing similar interests.
          </p>
        </div>

        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="bg-cyan-400/10 p-3 rounded-full w-12 h-12 flex items-center justify-center mb-4">
            <Palette className="w-6 h-6 text-cyan-400" />
          </div>
          <h3 className="text-lg font-semibold mb-2">Personal Branding</h3>
          <p className="text-gray-400">
            Build a distinctive presence on ZappaLink. Your badge helps create a cohesive personal brand 
            that reflects your professional identity.
          </p>
        </div>
      </div>

      {/* Important Note */}
      <div className="bg-gray-900 p-6 rounded-lg border border-gray-800">
        <div className="flex items-start space-x-4">
          <div className="bg-yellow-400/10 p-3 rounded-full">
            <Shield className="w-6 h-6 text-yellow-400" />
          </div>
          <div>
            <h3 className="text-lg font-semibold text-yellow-400 mb-2">Important Note</h3>
            <p className="text-gray-300 leading-relaxed">
              Badges on ZappaLink are not verification badges. They are a way to express your role 
              and identity within the community. While they help identify your profession or interests, 
              they do not verify credentials or authenticity. Users are encouraged to exercise their 
              own judgment when interacting with others.
            </p>
          </div>
        </div>
      </div>

      {/* Get Badge Button */}
      <div className="mt-8 text-center">
        <Link
          to="/hub/badge/selection"
          className="inline-flex items-center px-8 py-3 bg-gradient-to-r from-cyan-400 to-purple-400 text-gray-900 rounded-lg font-semibold hover:from-cyan-300 hover:to-purple-300 transition-colors shadow-lg shadow-cyan-400/10"
        >
          <BadgeCheck className="w-5 h-5 mr-2" />
          Get Your Badge
        </Link>
        <p className="mt-4 text-sm text-gray-400">
          Express your professional identity with a ZappaLink badge
        </p>
      </div>
    </div>
  );
}

export default BadgeInfo;