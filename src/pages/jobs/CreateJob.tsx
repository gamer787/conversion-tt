import React, { useState, useEffect } from 'react';
import { useNavigate, useParams, Link } from 'react-router-dom';
import { ChevronLeft, Plus, Minus, Upload, Clock, Eye } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { format } from 'date-fns';

interface JobFormData {
  title: string;
  companyName: string;
  companyLogo: string;
  location: string;
  type: string;
  salaryRange: string;
  description: string;
  requirements: string[];
  benefits: string[];
  expiresAt: string;
}

export default function CreateJob() {
  const navigate = useNavigate();
  const { id } = useParams<{ id: string }>();
  const [isBusinessAccount, setIsBusinessAccount] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [applications, setApplications] = useState<any[]>([]);
  const [formData, setFormData] = useState<JobFormData>({
    title: '',
    companyName: '',
    companyLogo: '',
    location: '',
    type: 'full-time',
    salaryRange: '',
    description: '',
    requirements: [''],
    benefits: [''],
    expiresAt: ''
  });

  useEffect(() => {
    checkAccountType();
    if (id) {
      Promise.all([
        loadJobDraft(id),
        loadJobApplications(id)
      ]);
    }
  }, [id]);

  const checkAccountType = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        navigate('/');
        return;
      }

      const { data: profile } = await supabase
        .from('profiles')
        .select('account_type')
        .eq('id', user.id)
        .single();

      if (profile?.account_type !== 'business') {
        navigate('/hub/jobs');
        return;
      }

      setIsBusinessAccount(true);
    } catch (error) {
      console.error('Error checking account type:', error);
      navigate('/hub/jobs');
    }
  };

  const loadJobApplications = async (jobId: string) => {
    try {
      const { data: applications, error } = await supabase.rpc('get_job_applications', {
        job_id: jobId 
      });

      if (error) throw error;
      setApplications(applications || []);
    } catch (err) {
      console.error('Error loading applications:', err);
    }
  };

  const loadJobDraft = async (draftId: string) => {
    try {
      const { data: draft, error } = await supabase.rpc('get_job_draft', {
        draft_id: draftId
      });

      if (error) throw error;
      if (draft?.[0]) {
        setFormData({
          title: draft[0].title,
          companyName: draft[0].company_name,
          companyLogo: draft[0].company_logo || '',
          location: draft[0].location,
          type: draft[0].type,
          salaryRange: draft[0].salary_range || '',
          description: draft[0].description,
          requirements: draft[0].requirements.length ? draft[0].requirements : [''],
          benefits: draft[0].benefits.length ? draft[0].benefits : [''],
          expiresAt: draft[0].expires_at ? format(new Date(draft[0].expires_at), 'yyyy-MM-dd') : ''
        });
      }
    } catch (err) {
      console.error('Error loading job draft:', err);
    }
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    setFormData(prev => ({
      ...prev,
      [e.target.name]: e.target.value
    }));
  };

  const handleArrayInput = (type: 'requirements' | 'benefits', index: number, value: string) => {
    setFormData(prev => {
      const newArray = [...prev[type]];
      newArray[index] = value;
      return { ...prev, [type]: newArray };
    });
  };

  const addArrayItem = (type: 'requirements' | 'benefits') => {
    setFormData(prev => ({
      ...prev,
      [type]: [...prev[type], '']
    }));
  };

  const removeArrayItem = (type: 'requirements' | 'benefits', index: number) => {
    setFormData(prev => ({
      ...prev,
      [type]: prev[type].filter((_, i) => i !== index)
    }));
  };

  const handleLogoUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    try {
      const file = e.target.files?.[0];
      if (!file) return;

      // Validate file
      if (!file.type.startsWith('image/')) {
        throw new Error('Please upload an image file');
      }
      if (file.size > 5 * 1024 * 1024) {
        throw new Error('File size must be less than 5MB');
      }

      setLoading(true);
      const fileExt = file.name.split('.').pop();
      const fileName = `${Math.random()}.${fileExt}`;
      const filePath = `company-logos/${fileName}`;

      const { error: uploadError } = await supabase.storage
        .from('logos')
        .upload(filePath, file);

      if (uploadError) throw uploadError;

      const { data: { publicUrl } } = supabase.storage
        .from('logos')
        .getPublicUrl(filePath);

      setFormData(prev => ({
        ...prev,
        companyLogo: publicUrl
      }));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to upload logo');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent, status: 'draft' | 'open') => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      // Filter out empty array items
      const requirements = formData.requirements.filter(r => r.trim());
      const benefits = formData.benefits.filter(b => b.trim());

      const { error } = await supabase
        .from('job_listings')
        .insert({
          user_id: user.id,
          title: formData.title,
          company_name: formData.companyName,
          company_logo: formData.companyLogo,
          location: formData.location,
          type: formData.type,
          salary_range: formData.salaryRange,
          description: formData.description,
          requirements,
          benefits,
          status,
          expires_at: formData.expiresAt ? new Date(formData.expiresAt).toISOString() : null
        });

      if (error) throw error;

      navigate('/hub/jobs');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create job listing');
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
        <div>
          <h1 className="text-2xl font-bold">Create Job Listing</h1>
          <p className="text-sm text-gray-400 mt-1">Post a new job opportunity</p>
        </div>
        <div className="ml-auto">
          <Link
            to="/hub/jobs"
            className="bg-gray-800 text-white px-6 py-2 rounded-lg font-semibold hover:bg-gray-700 transition-colors flex items-center space-x-2"
          >
            <Eye className="w-5 h-5" />
            <span>View My Jobs</span>
          </Link>
        </div>
      </div>

      <form onSubmit={(e) => handleSubmit(e, 'open')} className="space-y-6">
        {error && (
          <div className="bg-red-500/10 border border-red-500 text-red-500 rounded-lg p-4">
            {error}
          </div>
        )}

        <div className="space-y-4">
          {/* Applications Section */}
          {id && (
            <div className="bg-gray-900 p-6 rounded-lg space-y-4">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h2 className="text-lg font-semibold">Received Applications</h2>
                  <p className="text-sm text-gray-400 mt-1">
                    {applications.length} {applications.length === 1 ? 'application' : 'applications'} received
                  </p>
                </div>
                <Link
                  to={`/hub/jobs/${id}/applications`}
                  className="bg-cyan-400 text-gray-900 px-6 py-2 rounded-lg font-semibold hover:bg-cyan-300 transition-colors flex items-center space-x-2"
                >
                  <Eye className="w-5 h-5" />
                  <span>View All Applications</span>
                </Link>
              </div>
              {applications.length > 0 ? (
                <div className="space-y-4">
                  {applications.slice(0, 3).map((application) => (
                    <div 
                      key={application.id}
                      className="flex items-center justify-between p-4 bg-gray-800 rounded-lg"
                    >
                      <div className="flex items-center space-x-4">
                        <img
                          src={application.applicant_avatar || `https://ui-avatars.com/api/?name=${encodeURIComponent(application.applicant_name)}&background=random`}
                          alt={application.applicant_name}
                          className="w-10 h-10 rounded-full"
                        />
                        <div>
                          <h3 className="font-medium">{application.applicant_name}</h3>
                          <p className="text-sm text-gray-400">@{application.applicant_username}</p>
                          {application.applicant_badge && (
                            <span className="inline-block bg-cyan-400/10 text-cyan-400 text-xs px-2 py-0.5 rounded mt-1">
                              {application.applicant_badge.role}
                            </span>
                          )}
                        </div>
                      </div>
                      <div className="flex items-center space-x-4">
                        <span className={`text-xs px-2 py-1 rounded-full ${
                          application.status === 'unviewed'
                            ? 'bg-yellow-400/10 text-yellow-400'
                            : application.status === 'pending'
                            ? 'bg-blue-400/10 text-blue-400'
                            : application.status === 'accepted'
                            ? 'bg-green-400/10 text-green-400'
                            : 'bg-red-400/10 text-red-400'
                        }`}>
                          {application.status.charAt(0).toUpperCase() + application.status.slice(1)}
                        </span>
                        <Link
                          to={`/hub/jobs/${id}/applications`}
                          className="text-cyan-400 hover:text-cyan-300 transition-colors"
                        >
                          View Details
                        </Link>
                      </div>
                    </div>
                  ))}
                  {applications.length > 3 && (
                    <div className="text-center mt-4">
                      <Link
                        to={`/hub/jobs/${id}/applications`}
                        className="text-cyan-400 hover:text-cyan-300 transition-colors"
                      >
                        View {applications.length - 3} more applications
                      </Link>
                    </div>
                  )}
                </div>
              ) : (
                <div className="text-center py-8 bg-gray-800 rounded-lg">
                  <p className="text-gray-400">No applications received yet</p>
                </div>
              )}
            </div>
          )}

          {/* Basic Info */}
          <div className="bg-gray-900 p-6 rounded-lg space-y-4">
            <h2 className="text-lg font-semibold mb-4">Basic Information</h2>
            
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-1">
                Job Title
              </label>
              <input
                type="text"
                name="title"
                value={formData.title}
                onChange={handleInputChange}
                className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                placeholder="e.g., Senior Software Engineer"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-400 mb-1">
                Company Name
              </label>
              <input
                type="text"
                name="companyName"
                value={formData.companyName}
                onChange={handleInputChange}
                className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                placeholder="e.g., Acme Inc."
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-400 mb-1">
                Company Logo
              </label>
              <div className="flex items-center space-x-4">
                {formData.companyLogo && (
                  <img
                    src={formData.companyLogo}
                    alt="Company Logo"
                    className="w-16 h-16 rounded-lg object-contain bg-white"
                  />
                )}
                <label className="flex-1 cursor-pointer">
                  <div className="bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white hover:bg-gray-700 transition-colors">
                    <div className="flex items-center justify-center space-x-2">
                      <Upload className="w-5 h-5" />
                      <span>Upload Logo</span>
                    </div>
                  </div>
                  <input
                    type="file"
                    accept="image/*"
                    onChange={handleLogoUpload}
                    className="hidden"
                  />
                </label>
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-400 mb-1">
                Location
              </label>
              <input
                type="text"
                name="location"
                value={formData.location}
                onChange={handleInputChange}
                className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                placeholder="e.g., New York, NY (or Remote)"
                required
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-1">
                  Job Type
                </label>
                <select
                  name="type"
                  value={formData.type}
                  onChange={handleInputChange}
                  className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-cyan-400"
                  required
                >
                  <option value="full-time">Full-time</option>
                  <option value="part-time">Part-time</option>
                  <option value="contract">Contract</option>
                  <option value="internship">Internship</option>
                  <option value="freelance">Freelance</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-400 mb-1">
                  Salary Range
                </label>
                <input
                  type="text"
                  name="salaryRange"
                  value={formData.salaryRange}
                  onChange={handleInputChange}
                  className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                  placeholder="e.g., $80,000 - $120,000"
                />
              </div>
            </div>
          </div>

          {/* Description */}
          <div className="bg-gray-900 p-6 rounded-lg space-y-4">
            <h2 className="text-lg font-semibold mb-4">Job Description</h2>
            
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-1">
                Description
              </label>
              <textarea
                name="description"
                value={formData.description}
                onChange={handleInputChange}
                className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400 min-h-[200px]"
                placeholder="Describe the role, responsibilities, and ideal candidate..."
                required
              />
            </div>
          </div>

          {/* Requirements */}
          <div className="bg-gray-900 p-6 rounded-lg space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-semibold">Requirements</h2>
              <button
                type="button"
                onClick={() => addArrayItem('requirements')}
                className="text-cyan-400 hover:text-cyan-300 transition-colors"
              >
                <Plus className="w-5 h-5" />
              </button>
            </div>
            
            {formData.requirements.map((req, index) => (
              <div key={index} className="flex items-center space-x-2">
                <input
                  type="text"
                  value={req}
                  onChange={(e) => handleArrayInput('requirements', index, e.target.value)}
                  className="flex-1 bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                  placeholder="Add a requirement..."
                />
                <button
                  type="button"
                  onClick={() => removeArrayItem('requirements', index)}
                  className="text-red-400 hover:text-red-300 transition-colors p-2"
                >
                  <Minus className="w-5 h-5" />
                </button>
              </div>
            ))}
          </div>

          {/* Benefits */}
          <div className="bg-gray-900 p-6 rounded-lg space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-semibold">Benefits</h2>
              <button
                type="button"
                onClick={() => addArrayItem('benefits')}
                className="text-cyan-400 hover:text-cyan-300 transition-colors"
              >
                <Plus className="w-5 h-5" />
              </button>
            </div>
            
            {formData.benefits.map((benefit, index) => (
              <div key={index} className="flex items-center space-x-2">
                <input
                  type="text"
                  value={benefit}
                  onChange={(e) => handleArrayInput('benefits', index, e.target.value)}
                  className="flex-1 bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                  placeholder="Add a benefit..."
                />
                <button
                  type="button"
                  onClick={() => removeArrayItem('benefits', index)}
                  className="text-red-400 hover:text-red-300 transition-colors p-2"
                >
                  <Minus className="w-5 h-5" />
                </button>
              </div>
            ))}
          </div>

          {/* Expiry Date */}
          <div className="bg-gray-900 p-6 rounded-lg">
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-1">
                Listing Expires On
              </label>
              <input
                type="date"
                name="expiresAt"
                value={formData.expiresAt}
                onChange={handleInputChange}
                min={new Date().toISOString().split('T')[0]}
                className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-cyan-400"
              />
            </div>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="flex space-x-4">
          <button
            type="button"
            onClick={(e) => handleSubmit(e, 'draft')}
            disabled={loading}
            className="flex-1 bg-gray-800 text-white px-6 py-3 rounded-lg font-semibold hover:bg-gray-700 transition-colors disabled:opacity-50"
          >
            Save as Draft
          </button>
          <button
            type="submit"
            disabled={loading}
            className="flex-1 bg-cyan-400 text-gray-900 px-6 py-3 rounded-lg font-semibold hover:bg-cyan-300 transition-colors disabled:opacity-50"
          >
            {loading ? 'Publishing...' : 'Publish Job'}
          </button>
        </div>
      </form>
    </div>
  );
}