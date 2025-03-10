import React from 'react';
import { ChevronLeft, Building2, Briefcase, Users, Clock, MapPin, Globe, CheckCircle, Send } from 'lucide-react';
import { useNavigate, Link } from 'react-router-dom';

export default function JobInfo() {
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
        <h1 className="text-2xl font-bold">About Job Listings</h1>
      </div>

      {/* Hero Section */}
      <div className="bg-gradient-to-br from-cyan-400/20 to-purple-400/20 p-8 rounded-lg border border-cyan-400/20 mb-8">
        <div className="flex items-center justify-center mb-6">
          <Briefcase className="w-16 h-16 text-cyan-400" />
        </div>
        <h2 className="text-2xl font-bold text-center mb-4">Connect with Top Talent</h2>
        <p className="text-gray-300 text-center max-w-2xl mx-auto">
          Post job opportunities and connect with qualified candidates in your area. Our platform makes it easy to manage 
          job listings and track applications all in one place.
        </p>
      </div>

      {/* Features Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="bg-cyan-400/10 p-3 rounded-full w-12 h-12 flex items-center justify-center mb-4">
            <Building2 className="w-6 h-6 text-cyan-400" />
          </div>
          <h3 className="text-lg font-semibold mb-2">Company Profile</h3>
          <p className="text-gray-400">
            Showcase your company with a professional profile including logo, description, and location. 
            Build your employer brand.
          </p>
        </div>

        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="bg-cyan-400/10 p-3 rounded-full w-12 h-12 flex items-center justify-center mb-4">
            <Users className="w-6 h-6 text-cyan-400" />
          </div>
          <h3 className="text-lg font-semibold mb-2">Talent Pool</h3>
          <p className="text-gray-400">
            Access a diverse pool of qualified candidates. Review applications, resumes, and cover letters 
            all in one place.
          </p>
        </div>

        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="bg-cyan-400/10 p-3 rounded-full w-12 h-12 flex items-center justify-center mb-4">
            <Clock className="w-6 h-6 text-cyan-400" />
          </div>
          <h3 className="text-lg font-semibold mb-2">Flexible Listings</h3>
          <p className="text-gray-400">
            Post full-time, part-time, contract, or remote positions. Set custom expiration dates and 
            manage listing status.
          </p>
        </div>

        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="bg-cyan-400/10 p-3 rounded-full w-12 h-12 flex items-center justify-center mb-4">
            <MapPin className="w-6 h-6 text-cyan-400" />
          </div>
          <h3 className="text-lg font-semibold mb-2">Local Reach</h3>
          <p className="text-gray-400">
            Connect with talent in your area. Perfect for businesses looking to build local teams and 
            strengthen community presence.
          </p>
        </div>
      </div>

      {/* Additional Features */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="bg-cyan-400/10 p-3 rounded-full w-12 h-12 flex items-center justify-center mb-4">
            <Globe className="w-6 h-6 text-cyan-400" />
          </div>
          <h3 className="text-lg font-semibold mb-2">Wide Visibility</h3>
          <p className="text-gray-400">
            Your job listings reach a diverse audience of professionals. Track views and engagement to 
            measure your listing's performance.
          </p>
        </div>

        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="bg-cyan-400/10 p-3 rounded-full w-12 h-12 flex items-center justify-center mb-4">
            <CheckCircle className="w-6 h-6 text-cyan-400" />
          </div>
          <h3 className="text-lg font-semibold mb-2">Easy Management</h3>
          <p className="text-gray-400">
            Simple tools to post, edit, and manage job listings. Review applications efficiently and 
            communicate with candidates.
          </p>
        </div>

        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="bg-cyan-400/10 p-3 rounded-full w-12 h-12 flex items-center justify-center mb-4">
            <Send className="w-6 h-6 text-cyan-400" />
          </div>
          <h3 className="text-lg font-semibold mb-2">Direct Applications</h3>
          <p className="text-gray-400">
            Receive applications directly through the platform. Review resumes and cover letters in a 
            streamlined interface.
          </p>
        </div>
      </div>

      {/* How It Works */}
      <div className="bg-gray-900 p-8 rounded-lg mb-8">
        <h3 className="text-xl font-bold mb-6">How It Works</h3>
        <div className="space-y-6">
          <div className="flex items-start space-x-4">
            <div className="w-8 h-8 bg-cyan-400 text-gray-900 rounded-full flex items-center justify-center flex-shrink-0 font-bold">
              1
            </div>
            <div>
              <h4 className="font-semibold mb-2">Create Your Listing</h4>
              <p className="text-gray-400">
                Fill out the job details including title, description, requirements, and benefits. Add your 
                company logo and customize the listing to attract the right candidates.
              </p>
            </div>
          </div>

          <div className="flex items-start space-x-4">
            <div className="w-8 h-8 bg-cyan-400 text-gray-900 rounded-full flex items-center justify-center flex-shrink-0 font-bold">
              2
            </div>
            <div>
              <h4 className="font-semibold mb-2">Publish and Manage</h4>
              <p className="text-gray-400">
                Choose to publish immediately or save as a draft. Set an expiration date and monitor views. 
                Edit or close the listing at any time.
              </p>
            </div>
          </div>

          <div className="flex items-start space-x-4">
            <div className="w-8 h-8 bg-cyan-400 text-gray-900 rounded-full flex items-center justify-center flex-shrink-0 font-bold">
              3
            </div>
            <div>
              <h4 className="font-semibold mb-2">Review Applications</h4>
              <p className="text-gray-400">
                Receive applications through the platform. Review candidate profiles, resumes, and cover letters. 
                Track application status and communicate with applicants.
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* CTA */}
      <div className="text-center">
        <Link
          to="/hub/jobs/create"
          className="inline-flex items-center px-8 py-3 bg-gradient-to-r from-cyan-400 to-purple-400 text-gray-900 rounded-lg font-semibold hover:from-cyan-300 hover:to-purple-300 transition-colors shadow-lg shadow-cyan-400/10"
        >
          <Briefcase className="w-5 h-5 mr-2" />
          Post Your First Job
        </Link>
        <p className="mt-4 text-sm text-gray-400">
          Start connecting with qualified candidates today
        </p>
      </div>
    </div>
  );
}