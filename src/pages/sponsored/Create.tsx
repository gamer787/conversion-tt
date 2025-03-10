import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { ChevronLeft, Upload, DollarSign } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { handleAdPayment } from '../../lib/payments';

interface FormData {
  title: string;
  description: string;
  content_url: string;
  budget: number;
  target_audience: string[];
  start_time: string;
  end_time: string;
}

export default function CreateSponsored() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [isBusinessAccount, setIsBusinessAccount] = useState(false);
  const [formData, setFormData] = useState<FormData>({
    title: '',
    description: '',
    content_url: '',
    budget: 0,
    target_audience: [],
    start_time: '',
    end_time: ''
  });

  useEffect(() => {
    checkAccountType();
  }, []);

  const checkAccountType = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      const { data: profile } = await supabase
        .from('profiles')
        .select('account_type')
        .eq('id', user.id)
        .single();

      if (!profile) throw new Error('Profile not found');

      if (profile.account_type !== 'business') {
        navigate('/hub/sponsored');
        return;
      }

      setIsBusinessAccount(true);
    } catch (error) {
      console.error('Error checking account type:', error);
      navigate('/hub/sponsored');
    }
  };

  // Add additional check when component mounts
  useEffect(() => {
    const checkAccess = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        navigate('/hub/sponsored');
        return;
      }

      const { data: profile } = await supabase
        .from('profiles')
        .select('account_type')
        .eq('id', user.id)
        .single();

      if (profile?.account_type !== 'business') {
        navigate('/hub/sponsored');
      }
    };

    checkAccess();
  }, [navigate]);

  const handleContentUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    try {
      const file = e.target.files?.[0];
      if (!file) return;

      // Validate file
      if (!file.type.startsWith('image/') && !file.type.startsWith('video/')) {
        throw new Error('Please upload an image or video file');
      }
      if (file.size > 10 * 1024 * 1024) {
        throw new Error('File size must be less than 10MB');
      }

      setLoading(true);
      const fileExt = file.name.split('.').pop();
      const fileName = `${Math.random()}.${fileExt}`;
      const filePath = `sponsored/${fileName}`;

      const { error: uploadError, data } = await supabase.storage
        .from('content')
        .upload(filePath, file);

      if (uploadError) throw uploadError;

      const { data: { publicUrl } } = supabase.storage
        .from('content')
        .getPublicUrl(filePath);

      setFormData(prev => ({
        ...prev,
        content_url: publicUrl
      }));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to upload content');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      setLoading(true);
      setError(null);
      setSuccess(null);

      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      // Validate form data
      if (!formData.title.trim()) throw new Error('Title is required');
      if (!formData.description.trim()) throw new Error('Description is required');
      if (!formData.content_url) throw new Error('Content is required');
      if (formData.budget <= 0) throw new Error('Budget must be greater than 0');
      if (!formData.start_time || !formData.end_time) throw new Error('Start and end times are required');

      // Create sponsored content
      const { data: content, error: contentError } = await supabase
        .from('sponsored_content')
        .insert({
          user_id: user.id,
          title: formData.title,
          description: formData.description,
          content_url: formData.content_url,
          budget: formData.budget,
          target_audience: formData.target_audience,
          start_time: formData.start_time,
          end_time: formData.end_time,
          status: 'draft'
        })
        .select()
        .single();

      if (contentError) throw contentError;

      setSuccess('Sponsored content created successfully!');
      navigate('/hub/sponsored');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create sponsored content');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="pb-20 pt-4">
      <div className="flex items-center space-x-3 mb-8">
        <button
          onClick={() => navigate('/hub/sponsored')}
          className="p-2 hover:bg-gray-800 rounded-lg transition-colors"
        >
          <ChevronLeft className="w-6 h-6" />
        </button>
        <div>
          <h1 className="text-2xl font-bold">Create Sponsored Content</h1>
          <p className="text-sm text-gray-400 mt-1">Create a new sponsored content opportunity</p>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="space-y-6">
        {error && (
          <div className="bg-red-500/10 border border-red-500 text-red-500 rounded-lg p-4">
            {error}
          </div>
        )}

        {success && (
          <div className="bg-green-500/10 border border-green-500 text-green-500 rounded-lg p-4">
            {success}
          </div>
        )}

        <div className="space-y-4">
          {/* Basic Info */}
          <div className="bg-gray-900 p-6 rounded-lg space-y-4">
            <h2 className="text-lg font-semibold mb-4">Basic Information</h2>
            
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-1">
                Title
              </label>
              <input
                type="text"
                value={formData.title}
                onChange={(e) => setFormData(prev => ({ ...prev, title: e.target.value }))}
                className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                placeholder="e.g., Looking for Creative Content Creators"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-400 mb-1">
                Description
              </label>
              <textarea
                value={formData.description}
                onChange={(e) => setFormData(prev => ({ ...prev, description: e.target.value }))}
                className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400 min-h-[150px]"
                placeholder="Describe the opportunity and requirements..."
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-400 mb-1">
                Content
              </label>
              <div className="flex items-center space-x-4">
                {formData.content_url && (
                  <div className="w-24 h-24 bg-gray-800 rounded-lg overflow-hidden">
                    {formData.content_url.includes('.mp4') ? (
                      <video
                        src={formData.content_url}
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      <img
                        src={formData.content_url}
                        alt="Content preview"
                        className="w-full h-full object-cover"
                      />
                    )}
                  </div>
                )}
                <label className="flex-1 cursor-pointer">
                  <div className="bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white hover:bg-gray-700 transition-colors">
                    <div className="flex items-center justify-center space-x-2">
                      <Upload className="w-5 h-5" />
                      <span>Upload Content</span>
                    </div>
                  </div>
                  <input
                    type="file"
                    accept="image/*,video/*"
                    onChange={handleContentUpload}
                    className="hidden"
                  />
                </label>
              </div>
            </div>
          </div>

          {/* Budget and Timing */}
          <div className="bg-gray-900 p-6 rounded-lg space-y-4">
            <h2 className="text-lg font-semibold mb-4">Budget and Timing</h2>

            <div>
              <label className="block text-sm font-medium text-gray-400 mb-1">
                Budget (in INR)
              </label>
              <div className="relative">
                <DollarSign className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                <input
                  type="number"
                  value={formData.budget}
                  onChange={(e) => setFormData(prev => ({ ...prev, budget: parseInt(e.target.value) }))}
                  className="w-full bg-gray-800 border border-gray-700 rounded-lg pl-10 pr-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                  placeholder="Enter budget amount"
                  min="0"
                  required
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-1">
                  Start Date
                </label>
                <input
                  type="datetime-local"
                  value={formData.start_time}
                  onChange={(e) => setFormData(prev => ({ ...prev, start_time: e.target.value }))}
                  className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-cyan-400"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-400 mb-1">
                  End Date
                </label>
                <input
                  type="datetime-local"
                  value={formData.end_time}
                  onChange={(e) => setFormData(prev => ({ ...prev, end_time: e.target.value }))}
                  className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-cyan-400"
                  required
                />
              </div>
            </div>
          </div>

          {/* Target Audience */}
          <div className="bg-gray-900 p-6 rounded-lg space-y-4">
            <h2 className="text-lg font-semibold mb-4">Target Audience</h2>

            <div>
              <label className="block text-sm font-medium text-gray-400 mb-1">
                Target Demographics (comma-separated)
              </label>
              <input
                type="text"
                value={formData.target_audience.join(', ')}
                onChange={(e) => setFormData(prev => ({
                  ...prev,
                  target_audience: e.target.value.split(',').map(s => s.trim()).filter(Boolean)
                }))}
                className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                placeholder="e.g., 18-24, Students, Tech-savvy"
              />
            </div>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="flex space-x-4">
          <button
            type="button"
            onClick={() => navigate('/hub/sponsored')}
            className="flex-1 bg-gray-800 text-white px-6 py-3 rounded-lg font-semibold hover:bg-gray-700 transition-colors"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={loading}
            className="flex-1 bg-cyan-400 text-gray-900 px-6 py-3 rounded-lg font-semibold hover:bg-cyan-300 transition-colors disabled:opacity-50"
          >
            {loading ? 'Creating...' : 'Create Opportunity'}
          </button>
        </div>
      </form>
    </div>
  );
}