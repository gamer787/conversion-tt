import React, { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { ChevronLeft, Building2, MapPin, Clock, Eye, Users, Send, X, Check, Edit, Trash2, AlertTriangle } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { format } from 'date-fns';

interface JobListing {
  id: string;
  title: string;
  company_name: string;
  company_logo: string;
  location: string;
  type: string;
  salary_range: string;
  description: string;
  requirements: string[];
  benefits: string[];
  status: 'open' | 'closed' | 'draft';
  created_at: string;
  expires_at: string | null;
  views: number;
  user_id: string;
}

export default function JobDetails() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [job, setJob] = useState<JobListing | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [applying, setApplying] = useState(false);
  const [isOwner, setIsOwner] = useState(false);
  const [uploadingResume, setUploadingResume] = useState(false);
  const [application, setApplication] = useState({
    coverLetter: '',
    resumeUrl: '',
    email: '',
    phone: '',
    expectedSalary: '',
    isNegotiable: false,
    noticePeriod: '',
    currentCompany: '',
    currentRole: '',
    yearsOfExperience: '',
    currentLocation: '',
    willingToRelocate: false,
    preferredLocations: ''
  });
  const [hasApplied, setHasApplied] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);

  useEffect(() => {
    loadJob();
  }, [id]);

  const loadJob = async () => {
    try {
      setLoading(true);
      if (!id) throw new Error('Job ID is required');

      const { data: { user } } = await supabase.auth.getUser();
      const { data: job, error: jobError } = await supabase
        .from('job_listings')
        .select('*')
        .eq('id', id)
        .single();

      if (jobError) throw jobError;
      if (!job) throw new Error('Job not found');

      // Check if current user is the job owner
      setIsOwner(user?.id === job.user_id);

      // Only increment views for non-owners
      if (!isOwner) {
        await supabase.rpc('increment_job_views', { job_id: id });
      }

      setJob(job);

      // Check if user has already applied (only for non-owners)
      if (user) {
        const { data: application } = await supabase
          .from('job_applications')
          .select('id')
          .eq('job_id', id)
          .eq('applicant_id', user.id)
          .maybeSingle();

        setHasApplied(!!application);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load job details');
    } finally {
      setLoading(false);
    }
  };

  const handleResumeUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    try {
      const file = e.target.files?.[0];
      if (!file) {
        setError('Please select a file');
        return;
      }

      // Clear previous messages
      setError(null);
      setSuccess(null);
      setUploadingResume(true);

      // Validate file
      if (!file.type.includes('pdf')) {
        throw new Error('Please upload a PDF file');
      }
      if (file.size > 5 * 1024 * 1024) {
        throw new Error('File size must be less than 5MB');
      }

      // Generate unique filename
      const fileName = `${Math.random()}.pdf`;
      const filePath = `resumes/${fileName}`;

      const { error: uploadError } = await supabase.storage
        .from('resumes')
        .upload(filePath, file);

      if (uploadError) throw uploadError;

      const { data: { publicUrl } } = supabase.storage
        .from('resumes')
        .getPublicUrl(filePath);

      setApplication(prev => ({
        ...prev,
        resumeUrl: publicUrl
      }));
      
      setSuccess('Resume uploaded successfully!');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to upload resume');
    } finally {
      setUploadingResume(false);
    }
  };

  const handleApply = async () => {
    try {
      setApplying(true);
      setError(null);
      setSuccess(null);

      // Call the submit_job_application function with all fields
      const { data: applicationId, error } = await supabase.rpc('submit_job_application', {
        target_job_id: id,
        resume_url: application.resumeUrl, 
        cover_letter: application.coverLetter,
        email: application.email,
        phone: application.phone,
        expected_salary: application.expectedSalary,
        is_negotiable: application.isNegotiable,
        notice_period: application.noticePeriod,
        current_company: application.currentCompany,
        current_role: application.currentRole,
        years_of_experience: application.yearsOfExperience,
        current_location: application.currentLocation,
        willing_to_relocate: application.willingToRelocate,
        preferred_locations: application.preferredLocations
      });

      if (error) throw error;

      setHasApplied(true);
      setSuccess('Application submitted successfully!');
      setApplying(false);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to submit application');
      setApplying(false);
    }
  };

  const handleStatusChange = async (newStatus: 'open' | 'closed') => {
    try {
      const { error } = await supabase
        .from('job_listings')
        .update({ status: newStatus })
        .eq('id', id);

      if (error) throw error;

      if (job) {
        setJob({ ...job, status: newStatus });
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update job status');
    }
  };

  const handleDelete = async () => {
    try {
      const { data, error } = await supabase.rpc('delete_job_listing', {
        job_id: id
      });

      if (error) throw error;
      if (!data) throw new Error('Failed to delete job listing');

      navigate('/hub/jobs');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete job listing');
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center py-12">
        <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-cyan-400"></div>
      </div>
    );
  }

  if (error || !job) {
    return (
      <div className="text-center py-12">
        <p className="text-red-400">{error || 'Job not found'}</p>
        <button
          onClick={() => navigate('/hub/jobs')}
          className="mt-4 text-cyan-400 hover:text-cyan-300"
        >
          Back to Jobs
        </button>
      </div>
    );
  }

  return (
    <div className="pb-20 pt-4">
      <div className="flex items-center space-x-3 mb-8">
        <button
          onClick={() => navigate('/hub/jobs')}
          className="p-2 hover:bg-gray-800 rounded-lg transition-colors"
        >
          <ChevronLeft className="w-6 h-6" />
        </button>
        <h1 className="text-2xl font-bold">Job Details</h1>
      </div>

      <div className="space-y-6">
        {/* Header */}
        <div className="bg-gray-900 p-6 rounded-lg">
          <div className="flex items-start justify-between">
            <div className="flex items-start space-x-6">
              <div className="w-24 h-24 bg-white rounded-lg p-4 flex items-center justify-center">
                {job.company_logo ? (
                  <img
                    src={job.company_logo}
                    alt={job.company_name}
                    className="w-full h-full object-contain"
                  />
                ) : (
                  <Building2 className="w-12 h-12 text-gray-400" />
                )}
              </div>
              <div className="flex-1">
                <h2 className="text-2xl font-bold mb-2">{job.title}</h2>
                <p className="text-xl text-gray-400 mb-4">{job.company_name}</p>
                <div className="flex flex-wrap gap-4">
                  <div className="flex items-center text-gray-400">
                    <MapPin className="w-5 h-5 mr-2" />
                    <span>{job.location}</span>
                  </div>
                  <div className="flex items-center text-gray-400">
                    <Clock className="w-5 h-5 mr-2" />
                    <span>{job.type}</span>
                  </div>
                  {job.salary_range && (
                    <div className="text-cyan-400 font-medium">
                      {job.salary_range}
                    </div>
                  )}
                </div>
              </div>
            </div>
            {isOwner && (
              <div className="flex items-center space-x-3">
                <Link
                  to={`/hub/jobs/create/${id}`}
                  className="bg-gray-800 text-white px-6 py-2 rounded-lg font-semibold hover:bg-gray-700 transition-colors flex items-center space-x-2"
                >
                  <Edit className="w-5 h-5" />
                  <span>Edit</span>
                </Link>
                <button
                  onClick={() => handleStatusChange(job.status === 'open' ? 'closed' : 'open')}
                  className={`px-6 py-2 rounded-lg font-semibold transition-colors flex items-center space-x-2 ${
                    job.status === 'open'
                      ? 'bg-red-500 text-white hover:bg-red-600'
                      : 'bg-green-500 text-white hover:bg-green-600'
                  }`}
                >
                  {job.status === 'open' ? (
                    <>
                      <X className="w-5 h-5" />
                      <span>Close Listing</span>
                    </>
                  ) : (
                    <>
                      <Check className="w-5 h-5" />
                      <span>Reopen Listing</span>
                    </>
                  )}
                </button>
                <button
                  onClick={() => setShowDeleteConfirm(true)}
                  className="bg-red-500/10 text-red-500 px-6 py-2 rounded-lg font-semibold hover:bg-red-500/20 transition-colors flex items-center space-x-2"
                >
                  <Trash2 className="w-5 h-5" />
                  <span>Delete</span>
                </button>
              </div>
            )}
          </div>
        </div>

        {/* Description */}
        <div className="bg-gray-900 p-6 rounded-lg">
          <h3 className="text-lg font-semibold mb-4">Job Description</h3>
          <div className="prose prose-invert max-w-none">
            {job.description.split('\n').map((paragraph, index) => (
              <p key={index} className="mb-4 text-gray-300">
                {paragraph}
              </p>
            ))}
          </div>
        </div>

        {/* Requirements */}
        <div className="bg-gray-900 p-6 rounded-lg">
          <h3 className="text-lg font-semibold mb-4">Requirements</h3>
          <ul className="space-y-2">
            {job.requirements.map((req, index) => (
              <li key={index} className="flex items-start text-gray-300">
                <span className="w-2 h-2 mt-2 mr-3 bg-cyan-400 rounded-full" />
                {req}
              </li>
            ))}
          </ul>
        </div>

        {/* Benefits */}
        <div className="bg-gray-900 p-6 rounded-lg">
          <h3 className="text-lg font-semibold mb-4">Benefits</h3>
          <ul className="space-y-2">
            {job.benefits.map((benefit, index) => (
              <li key={index} className="flex items-start text-gray-300">
                <span className="w-2 h-2 mt-2 mr-3 bg-cyan-400 rounded-full" />
                {benefit}
              </li>
            ))}
          </ul>
        </div>

        {/* Status Messages */}
        {error && (
          <div className="bg-red-400/10 border border-red-400 text-red-400 rounded-lg p-4">
            {error}
          </div>
        )}

        {success && (
          <div className="bg-green-400/10 border border-green-400 text-green-400 rounded-lg p-4">
            {success}
          </div>
        )}

        {/* Application Form */}
        {job.status === 'open' && !hasApplied && !isOwner && (
          <div className="bg-gray-900 p-6 rounded-lg">
            <h3 className="text-lg font-semibold mb-4">Apply for this Position</h3>
            <div className="space-y-6">
              {/* Contact Information */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-1">
                    Email Address
                  </label>
                  <input
                    type="email"
                    value={application.email}
                    onChange={(e) => setApplication(prev => ({ ...prev, email: e.target.value }))}
                    className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                    placeholder="Enter your email address"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-1">
                    Phone Number
                  </label>
                  <input
                    type="tel"
                    value={application.phone}
                    onChange={(e) => setApplication(prev => ({ ...prev, phone: e.target.value }))}
                    className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                    placeholder="Enter your phone number"
                    required
                  />
                </div>
              </div>

              {/* Location Information */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-1">
                    Current Location
                  </label>
                  <input
                    type="text"
                    value={application.currentLocation}
                    onChange={(e) => setApplication(prev => ({ ...prev, currentLocation: e.target.value }))}
                    className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                    placeholder="e.g., New York, NY"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-1">
                    Preferred Locations
                  </label>
                  <input
                    type="text"
                    value={application.preferredLocations}
                    onChange={(e) => setApplication(prev => ({ ...prev, preferredLocations: e.target.value }))}
                    className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                    placeholder="e.g., San Francisco, London, Remote"
                  />
                </div>
              </div>

              <div>
                <div className="flex items-center space-x-2">
                  <input
                    type="checkbox"
                    id="willingToRelocate"
                    checked={application.willingToRelocate}
                    onChange={(e) => setApplication(prev => ({ ...prev, willingToRelocate: e.target.checked }))}
                    className="w-4 h-4 bg-gray-800 border-gray-700 rounded text-cyan-400 focus:ring-cyan-400"
                  />
                  <label htmlFor="willingToRelocate" className="text-sm font-medium text-gray-400">
                    I am willing to relocate for this position
                  </label>
                </div>
              </div>

              {/* Professional Information */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-1">
                    Current Company
                  </label>
                  <input
                    type="text"
                    value={application.currentCompany}
                    onChange={(e) => setApplication(prev => ({ ...prev, currentCompany: e.target.value }))}
                    className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                    placeholder="Enter your current company"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-1">
                    Current Role
                  </label>
                  <input
                    type="text"
                    value={application.currentRole}
                    onChange={(e) => setApplication(prev => ({ ...prev, currentRole: e.target.value }))}
                    className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                    placeholder="Enter your current role"
                  />
                </div>
              </div>

              {/* Experience and Notice Period */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-1">
                    Years of Experience
                  </label>
                  <input
                    type="number"
                    value={application.yearsOfExperience}
                    onChange={(e) => setApplication(prev => ({ ...prev, yearsOfExperience: e.target.value }))}
                    className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                    placeholder="Enter years of experience"
                    min="0"
                    step="0.5"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-1">
                    Notice Period
                  </label>
                  <input
                    type="text"
                    value={application.noticePeriod}
                    onChange={(e) => setApplication(prev => ({ ...prev, noticePeriod: e.target.value }))}
                    className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                    placeholder="e.g., 30 days, 2 months"
                    required
                  />
                </div>
              </div>

              {/* Salary Expectations */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-1">
                    Expected Salary
                  </label>
                  <input
                    type="text"
                    value={application.expectedSalary}
                    onChange={(e) => setApplication(prev => ({ ...prev, expectedSalary: e.target.value }))}
                    className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
                    placeholder="e.g., $80,000/year"
                    required
                  />
                </div>

                <div className="flex items-center space-x-2">
                  <input
                    type="checkbox"
                    id="negotiable"
                    checked={application.isNegotiable}
                    onChange={(e) => setApplication(prev => ({ ...prev, isNegotiable: e.target.checked }))}
                    className="w-4 h-4 bg-gray-800 border-gray-700 rounded text-cyan-400 focus:ring-cyan-400"
                  />
                  <label htmlFor="negotiable" className="text-sm font-medium text-gray-400">
                    Salary is negotiable
                  </label>
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-400 mb-1">
                  Cover Letter
                </label>
                <textarea
                  value={application.coverLetter}
                  onChange={(e) => setApplication(prev => ({ ...prev, coverLetter: e.target.value }))}
                  className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400 min-h-[200px]"
                  placeholder="Tell us why you're interested in this position..."
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-400 mb-1">
                  Resume (PDF)
                </label>
                <input
                  type="file"
                  accept=".pdf"
                  onChange={handleResumeUpload}
                  className="block w-full text-sm text-gray-400
                    file:mr-4 file:py-2 file:px-4
                    file:rounded-lg file:border-0 
                    file:text-sm file:font-medium
                    file:bg-cyan-400 file:text-gray-900
                    hover:file:bg-cyan-300
                    file:cursor-pointer cursor-pointer"
                />
                {uploadingResume && (
                  <div className="mt-2 flex items-center text-sm text-gray-400">
                    <div className="animate-spin rounded-full h-4 w-4 border-t-2 border-b-2 border-cyan-400 mr-2"></div>
                    Uploading resume...
                  </div>
                )}
              </div>

              <button
                onClick={handleApply}
                disabled={
                  applying || 
                  !application.coverLetter || 
                  !application.resumeUrl ||
                  !application.email ||
                  !application.phone ||
                  !application.expectedSalary ||
                  !application.noticePeriod ||
                  !application.yearsOfExperience ||
                  !application.currentLocation
                }
                className="w-full bg-cyan-400 text-gray-900 py-3 rounded-lg font-semibold hover:bg-cyan-300 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center space-x-2"
              >
                <Send className="w-5 h-5" />
                <span>{applying ? 'Submitting...' : 'Submit Application'}</span>
              </button>
            </div>
          </div>
        )}

        {isOwner && job.status === 'open' && (
          <div className="bg-gray-900 p-6 rounded-lg">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-lg font-semibold">Manage Applications</h3>
                <p className="text-gray-400 mt-1">Review and manage job applications</p>
              </div>
              <Link
                to={`/hub/jobs/${id}/applications`}
                className="bg-cyan-400 text-gray-900 px-6 py-2 rounded-lg font-semibold hover:bg-cyan-300 transition-colors"
              >
                View All Applications
              </Link>
            </div>
          </div>
        )}

        {hasApplied && (
          <div className="bg-green-400/10 border border-green-400 text-green-400 rounded-lg p-4">
            You have already applied for this position
          </div>
        )}

        {job.status === 'closed' && !isOwner && (
          <div className="bg-red-400/10 border border-red-400 text-red-400 rounded-lg p-4">
            This position is no longer accepting applications
          </div>
        )}

        {/* Delete Confirmation Modal */}
        {showDeleteConfirm && (
          <div className="fixed inset-0 bg-black/75 flex items-center justify-center z-50 p-4">
            <div className="bg-gray-900 rounded-lg p-6 max-w-md w-full">
              <div className="flex items-center space-x-3 text-red-500 mb-4">
                <AlertTriangle className="w-6 h-6" />
                <h3 className="text-xl font-bold">Delete Job Listing</h3>
              </div>
              <p className="text-gray-300 mb-4">
                Are you sure you want to delete this job listing? This action cannot be undone.
              </p>
              <div className="bg-gray-800 p-4 rounded-lg mb-6">
                <h4 className="font-semibold">{job.title}</h4>
                <p className="text-gray-400">{job.company_name}</p>
              </div>
              <div className="flex space-x-4">
                <button
                  onClick={() => setShowDeleteConfirm(false)}
                  className="flex-1 bg-gray-800 text-white px-4 py-2 rounded-lg hover:bg-gray-700 transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={handleDelete}
                  className="flex-1 bg-red-500 text-white px-4 py-2 rounded-lg hover:bg-red-600 transition-colors"
                >
                  Delete
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Footer Info */}
        <div className="flex items-center justify-between text-sm text-gray-400 mt-4">
          <div className="flex items-center space-x-4">
            <div className="flex items-center">
              <Eye className="w-4 h-4 mr-1" />
              <span>{job.views} views</span>
            </div>
            <div>
              Posted {format(new Date(job.created_at), 'MMM d, yyyy')}
            </div>
            {job.expires_at && (
              <div>
                Expires {format(new Date(job.expires_at), 'MMM d, yyyy')}
              </div>
            )}
          </div>
          <div className={`px-3 py-1 rounded-full ${
            job.status === 'open'
              ? 'bg-green-400/10 text-green-400'
              : 'bg-red-400/10 text-red-400'
          }`}>
            {job.status.charAt(0).toUpperCase() + job.status.slice(1)}
          </div>
        </div>
      </div>
    </div>
  );
}
