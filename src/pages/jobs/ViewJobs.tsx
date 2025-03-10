import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { ChevronLeft, Building2, MapPin, Clock, Eye, Users, Edit, X, Search, Filter, SortAsc, Briefcase, Trash2, AlertTriangle, Plus } from 'lucide-react';
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
  applications_count: number;
  user_id: string;
}

function ViewJobs() {
  const navigate = useNavigate();
  const [jobs, setJobs] = useState<JobListing[]>([]);
  const [isBusinessAccount, setIsBusinessAccount] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [filterType, setFilterType] = useState<'all' | 'open' | 'closed' | 'draft'>('open');
  const [sortBy, setSortBy] = useState<'date' | 'views' | 'applications'>('date');
  const [loading, setLoading] = useState(true);
  const [loadingApplications, setLoadingApplications] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [userApplications, setUserApplications] = useState<Set<string>>(new Set());
  const [jobToDelete, setJobToDelete] = useState<JobListing | null>(null);
  const [hasCreatedJobs, setHasCreatedJobs] = useState(false);

  useEffect(() => {
    loadJobs();
  }, [filterType]);

  useEffect(() => {
    supabase.auth.getUser().then(({ data: { user } }) => {
      setCurrentUserId(user?.id || null);
      checkAccountType(user?.id);
    });
  }, []);

  const checkAccountType = async (userId: string | undefined) => {
    if (!userId) return;
    
    try {
      const { data: profile } = await supabase
        .from('profiles')
        .select('account_type')
        .eq('id', userId)
        .single();

      setIsBusinessAccount(profile?.account_type === 'business');
      if (profile?.account_type === 'business') {
        checkUserJobs(userId);
      }
    } catch (error) {
      console.error('Error checking account type:', error);
    }
  };

  const checkUserJobs = async (userId: string) => {
    try {
      const { data: jobs } = await supabase
        .from('job_listings')
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'open')
        .limit(1);

      setHasCreatedJobs(!!jobs?.length);
    } catch (err) {
      console.error('Error checking user jobs:', err);
    }
  };

  const loadJobs = async () => {
    try {
      setLoading(true);
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        navigate('/');
        return;
      }

      // Start building the query
      let query = supabase
        .from('job_listings')
        .select(`
          *,
          applications:job_applications(count)
        `);

      // Apply filters
      if (filterType !== 'all') {
        query = query.eq('status', filterType);
      } else {
        // Never show closed jobs in the main listing unless specifically filtered
        query = query.neq('status', 'closed');
      }

      // Handle visibility based on account type
      if (isBusinessAccount) {
        query = query.or(`user_id.eq.${user.id},and(status.eq.open,user_id.neq.${user.id})`);
      } else {
        // For regular users, only show open jobs
        query = query.eq('status', 'open');
      }

      const { data: jobs, error: jobsError } = await query.order('created_at', { ascending: false });


      // Get user's applications if logged in
      let userApplications = [];
      if (user) {
        const { data: applications } = await supabase
          .from('job_applications')
          .select('job_id')
          .eq('applicant_id', user.id);
        userApplications = applications?.map(app => app.job_id) || [];
      }

      // Transform jobs data
      const transformedJobs = jobs?.map(job => ({
        ...job,
        applications_count: job.applications?.[0]?.count || 0,
        has_applied: userApplications.includes(job.id)
      })) || [];

      setJobs(transformedJobs);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load jobs');
    } finally {
      setLoading(false);
    }
  };

  const handleApply = (jobId: string) => {
    navigate(`/hub/jobs/${jobId}`);
  };

  const filteredJobs = jobs.filter(job => {
    const searchLower = searchQuery.toLowerCase();
    return (
      job.title.toLowerCase().includes(searchLower) ||
      job.company_name.toLowerCase().includes(searchLower) ||
      job.location.toLowerCase().includes(searchLower) ||
      job.description.toLowerCase().includes(searchLower)
    );
  });

  const sortedJobs = [...filteredJobs].sort((a, b) => {
    switch (sortBy) {
      case 'views':
        return b.views - a.views;
      case 'applications':
        return b.applications_count - a.applications_count;
      default:
        return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
    }
  });

  const handleStatusChange = async (jobId: string, newStatus: 'open' | 'closed') => {
    try {
      const { error } = await supabase
        .from('job_listings')
        .update({ status: newStatus })
        .eq('id', jobId);

      if (error) throw error;

      setJobs(prev => prev.map(job => 
        job.id === jobId ? { ...job, status: newStatus } : job
      ));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update job status');
    }
  };

  const loadApplicationCount = async (jobId: string) => {
    try {
      setLoadingApplications(true);
      const { count } = await supabase
        .from('job_applications')
        .select('*', { count: 'exact', head: true })
        .eq('job_id', jobId);

      return count || 0;
    } catch (err) {
      console.error('Error loading application count:', err);
      return 0;
    } finally {
      setLoadingApplications(false);
    }
  };

  const handleViewApplications = (jobId: string) => {
    navigate(`/hub/jobs/${jobId}/applications`);
  };

  const handleDelete = async () => {
    if (!jobToDelete) return;
    
    try {
      const { data, error } = await supabase.rpc('delete_job_listing', {
        job_id: jobToDelete.id
      });

      if (error) throw error;
      if (!data) throw new Error('Failed to delete job listing');

      // Update UI
      setJobs(prev => prev.filter(job => job.id !== jobToDelete.id));
      setJobToDelete(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete job listing');
    }
  };

  return (
    <div className="pb-20 pt-4">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 mb-6">
        <div className="flex items-center space-x-3 w-full sm:w-auto">
          <button
            onClick={() => navigate('/hub')}
            className="p-2 hover:bg-gray-800 rounded-lg transition-colors"
          >
            <ChevronLeft className="w-6 h-6" />
          </button>
          <div>
            <h1 className="text-2xl font-bold">Job Listings</h1>
            <p className="text-sm text-gray-400 mt-1">
              {isBusinessAccount ? 'Manage your job listings' : 'Find your next opportunity'}
            </p>
          </div>
        </div>
      </div>

      {/* Business Account Management Section */}
      {isBusinessAccount && (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
          <Link
            to="/hub/jobs/create"
            className="bg-gray-900 p-6 rounded-lg hover:bg-gray-800 transition-colors"
          >
            <div className="flex flex-col items-center text-center">
              <div className="bg-cyan-400/10 p-4 rounded-full mb-4">
                <Plus className="w-8 h-8 text-cyan-400" />
              </div>
              <h3 className="font-semibold mb-2">Post New Job</h3>
              <p className="text-sm text-gray-400">Create a new job listing</p>
            </div>
          </Link>

          <Link
            to="/hub/jobs/applications"
            className="bg-gray-900 p-6 rounded-lg hover:bg-gray-800 transition-colors"
          >
            <div className="flex flex-col items-center text-center">
              <div className="bg-cyan-400/10 p-4 rounded-full mb-4">
                <Users className="w-8 h-8 text-cyan-400" />
              </div>
              <h3 className="font-semibold mb-2">View Applications</h3>
              <p className="text-sm text-gray-400">Manage received applications</p>
            </div>
          </Link>

          <div
            className="bg-gray-900 p-6 rounded-lg hover:bg-gray-800 transition-colors cursor-pointer"
            onClick={() => setFilterType('draft')}
          >
            <div className="flex flex-col items-center text-center">
              <div className="bg-cyan-400/10 p-4 rounded-full mb-4">
                <Edit className="w-8 h-8 text-cyan-400" />
              </div>
              <h3 className="font-semibold mb-2">Manage Drafts</h3>
              <p className="text-sm text-gray-400">Edit your saved drafts</p>
            </div>
          </div>
        </div>
      )}

      {/* Search and Filters */}
      <div className="bg-gray-900 p-4 rounded-lg mb-6">
        <div className="flex flex-col lg:flex-row gap-4">
          {/* Search */}
          <div className="flex-1 relative">
            <input
              type="text"
              placeholder="Search jobs by title, description, or location..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full bg-gray-800 border border-gray-700 rounded-lg pl-10 pr-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-400"
            />
            <Search className="absolute left-3 top-2.5 text-gray-500 w-5 h-5" />
          </div>

          {/* Filter and Sort */}
          <div className="flex flex-wrap gap-2">
            <div className="relative">
              <select
                value={filterType}
                onChange={(e) => setFilterType(e.target.value as any)}
                className="w-full sm:w-auto flex items-center space-x-2 bg-gray-800 px-4 py-2 rounded-lg hover:bg-gray-700 transition-colors"
              >
                <option value="all">All Jobs</option>
                <option value="open">Open</option>
                <option value="closed">Closed</option>
                <option value="draft">Drafts</option>
              </select>
            </div>

            <button
              onClick={() => setSortBy(current => 
                current === 'date' ? 'views' : 'date'
              )}
              className="w-full sm:w-auto flex items-center justify-center space-x-2 bg-gray-800 px-4 py-2 rounded-lg hover:bg-gray-700 transition-colors"
            >
              <SortAsc className="w-5 h-5" />
              <span className="capitalize">
                {sortBy === 'date' ? 'Newest' : 'Most Viewed'}
              </span>
            </button>
          </div>
        </div>
      </div>

      {/* Job Listings */}
      {jobs.length === 0 ? (
        <div className="text-center py-12 bg-gray-900 rounded-lg">
          <Building2 className="w-12 h-12 text-gray-500 mx-auto mb-4" />
          <h2 className="text-xl font-semibold mb-2">No open positions available</h2>
          <p className="text-gray-400">
            Check back later for new opportunities
          </p>
        </div>
      ) : (
        <div className="grid gap-6">
          {jobs.map((job) => (
            <div key={job.id} className="bg-gray-900 rounded-lg overflow-hidden border border-gray-800 hover:border-gray-700 transition-colors p-4 sm:p-6">
              <div className="p-6 space-y-4">
                <div className="flex flex-col sm:flex-row items-start gap-4">
                  <div className="flex items-start space-x-4 w-full sm:w-auto">
                    <div className="w-16 h-16 bg-white rounded-lg p-2 flex items-center justify-center border border-gray-200">
                      {job.company_logo ? (
                        <img
                          src={job.company_logo}
                          alt={job.company_name}
                          className="w-full h-full object-contain"
                        />
                      ) : (
                        <Building2 className="w-8 h-8 text-gray-500" />
                      )}
                    </div>
                    <div className="flex-1">
                      <h2 className="text-xl font-semibold hover:text-cyan-400 transition-colors">
                        {job.title}
                      </h2>
                      <p className="text-gray-400 mt-1">{job.company_name}</p>
                      <div className="flex flex-wrap items-center gap-2 sm:gap-4 mt-3">
                        <div className="flex items-center text-gray-400">
                          <MapPin className="w-4 h-4 mr-1" />
                          <span className="text-sm">{job.location}</span>
                        </div>
                        <div className="flex items-center text-gray-400">
                          <Clock className="w-4 h-4 mr-1" />
                          <span className="text-sm">{job.type}</span>
                        </div>
                        {job.salary_range && (
                          <div className="text-sm text-cyan-400 font-medium">
                            {job.salary_range}
                          </div>
                        )}
                      </div>
                    </div>
                  </div>

                  <div className="w-full sm:w-auto mt-4 sm:mt-0">
                    <button
                      onClick={() => navigate(`/hub/jobs/${job.id}`)}
                      className="w-full sm:w-auto bg-cyan-400 text-gray-900 px-6 py-2 rounded-lg font-semibold hover:bg-cyan-300 transition-colors"
                    >
                      View Details
                    </button>
                  </div>
                </div>

                {/* Expiry Date */}
                {job.expires_at && (
                  <div className="mt-4 text-sm text-gray-400">
                    Applications close {format(new Date(job.expires_at), 'MMM d, yyyy')}
                  </div>
                )}

                {/* Job Stats */}
                <div className="flex flex-wrap items-center gap-4 mt-4 pt-4 border-t border-gray-800">
                  <div className="flex items-center text-gray-400">
                    <Eye className="w-4 h-4 mr-1" />
                    <span>{job.views} views</span>
                  </div>
                  <div className="flex items-center text-gray-400">
                    <Users className="w-4 h-4 mr-1" />
                    <span>{job.applications_count} applications</span>
                  </div>
                  <div className={`px-3 py-1 rounded-full text-sm ${
                    job.status === 'open'
                      ? 'bg-green-400/10 text-green-400'
                      : 'bg-red-400/10 text-red-400'
                  }`}>
                    {job.status.charAt(0).toUpperCase() + job.status.slice(1)}
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {jobToDelete && (
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
              <h4 className="font-semibold">{jobToDelete.title}</h4>
              <p className="text-gray-400">{jobToDelete.company_name}</p>
            </div>
            <div className="flex space-x-4">
              <button
                onClick={() => setJobToDelete(null)}
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

      {error && (
        <div className="fixed bottom-4 right-4 bg-red-500/10 border border-red-500 text-red-500 rounded-lg p-4 max-w-md">
          {error}
        </div>
      )}
    </div>
  );
}

export default ViewJobs;