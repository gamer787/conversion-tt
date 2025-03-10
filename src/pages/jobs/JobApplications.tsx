import React, { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { ChevronLeft, Building2, Download, CheckCircle, XCircle, Clock, Eye } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { format } from 'date-fns';
import { CommentsModal } from '../../components/CommentsModal';

interface Application {
  id: string;
  applicant_id: string;
  status: 'unviewed' | 'pending' | 'accepted' | 'rejected' | 'on_hold';
  created_at: string;
  updated_at: string;
  resume_url: string;
  cover_letter: string;
  applicant_name: string;
  applicant_username: string;
  applicant_avatar: string;
  applicant_badge?: {
    role: string;
  };
}

interface JobDetails {
  id: string;
  title: string;
  company_name: string;
  company_logo: string | null;
  location: string;
  type: string;
  status: string;
}

export default function JobApplications() {
  const { jobId } = useParams<{ jobId: string }>();
  const navigate = useNavigate();
  const [applications, setApplications] = useState<Application[]>([]);
  const [jobDetails, setJobDetails] = useState<JobDetails | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedApplication, setSelectedApplication] = useState<Application | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadApplications();
    loadJobDetails();
  }, [jobId]);

  const loadJobDetails = async () => {
    try {
      const { data: job, error } = await supabase
        .from('job_listings')
        .select('*')
        .eq('id', jobId)
        .single();

      if (error) throw error;
      setJobDetails(job);
    } catch (err) {
      console.error('Error loading job details:', err);
    }
  };

  const loadApplications = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase.rpc('get_job_applications', {
        job_id: jobId
      });

      if (error) throw error;
      setApplications(data || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load applications');
    } finally {
      setLoading(false);
    }
  };

  const handleStatusChange = async (applicationId: string, newStatus: Application['status']) => {
    try {
      const { error } = await supabase.rpc('update_application_status', {
        application_id: applicationId,
        new_status: newStatus
      });

      if (error) throw error;

      // Update UI
      setApplications(prev => prev.map(app => 
        app.id === applicationId ? { ...app, status: newStatus } : app
      ));

      // If accepting, close the job listing
      if (newStatus === 'accepted') {
        const { error: updateError } = await supabase
          .from('job_listings')
          .update({ status: 'closed' })
          .eq('id', jobId);

        if (updateError) throw updateError;
        if (jobDetails) {
          setJobDetails({ ...jobDetails, status: 'closed' });
        }
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update application status');
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center py-12">
        <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-cyan-400"></div>
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
        <div className="flex-1">
          <h1 className="text-2xl font-bold">Applications</h1>
          {jobDetails && (
            <p className="text-sm text-gray-400 mt-1">
              {jobDetails.title} • {jobDetails.company_name}
            </p>
          )}
        </div>
      </div>

      {error && (
        <div className="bg-red-500/10 border border-red-500 text-red-500 rounded-lg p-4 mb-6">
          {error}
        </div>
      )}

      {applications.length === 0 ? (
        <div className="text-center py-12 bg-gray-900 rounded-lg">
          <Building2 className="w-12 h-12 text-gray-500 mx-auto mb-4" />
          <h2 className="text-xl font-semibold mb-2">No applications yet</h2>
          <p className="text-gray-400">
            When candidates apply for this position, they'll appear here
          </p>
        </div>
      ) : (
        <div className="space-y-6">
          {applications.map((application) => (
            <div 
              onClick={() => setSelectedApplication(application)}
              key={application.id}
              className="bg-gray-900 rounded-lg overflow-hidden border border-gray-800 cursor-pointer hover:border-gray-700 transition-colors"
            >
              <div className="p-6">
                <div className="flex items-start justify-between">
                  <div className="flex items-start space-x-4">
                    <Link to={`/profile/${application.applicant_username}`}>
                      <img
                        src={application.applicant_avatar || `https://ui-avatars.com/api/?name=${encodeURIComponent(application.applicant_name)}&background=random`}
                        alt={application.applicant_name}
                        className="w-12 h-12 rounded-full"
                      />
                    </Link>
                    <div>
                      <Link 
                        to={`/profile/${application.applicant_username}`}
                        className="font-semibold hover:text-cyan-400 transition-colors"
                      >
                        {application.applicant_name}
                      </Link>
                      <div className="flex items-center space-x-2">
                        <p className="text-gray-400">@{application.applicant_username}</p>
                        {application.applicant_badge && (
                          <span className="bg-cyan-400/10 text-cyan-400 px-2 py-0.5 rounded text-xs">
                            {application.applicant_badge.role}
                          </span>
                        )}
                      </div>
                      <div className="flex items-center space-x-4 mt-2">
                        <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm ${
                          application.status === 'unviewed'
                            ? 'bg-yellow-400/10 text-yellow-400'
                            : application.status === 'pending'
                            ? 'bg-blue-400/10 text-blue-400'
                            : application.status === 'on_hold'
                            ? 'bg-purple-400/10 text-purple-400'
                            : application.status === 'accepted'
                            ? 'bg-green-400/10 text-green-400'
                            : 'bg-red-400/10 text-red-400'
                        }`}>
                          <Clock className="w-4 h-4 mr-1" />
                          {application.status.charAt(0).toUpperCase() + application.status.slice(1)}
                        </span>
                        <span className="text-sm text-gray-400">
                          Applied {format(new Date(application.created_at), 'MMM d, yyyy')}
                        </span>
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center space-x-2">
                    {application.resume_url && (
                      <a
                        href={application.resume_url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="p-2 text-gray-400 hover:text-cyan-400 hover:bg-gray-800 rounded-lg transition-colors"
                        title="Download Resume"
                      >
                        <Download className="w-5 h-5" />
                      </a>
                    )}
                    {application.status !== 'accepted' && application.status !== 'rejected' && (
                      <>
                        <button
                          onClick={() => handleStatusChange(application.id, 'on_hold')}
                          className="p-2 text-gray-400 hover:text-purple-400 hover:bg-gray-800 rounded-lg transition-colors"
                          title="Put Application On Hold"
                        >
                          <Clock className="w-5 h-5" />
                        </button>
                        <button
                          onClick={() => handleStatusChange(application.id, 'accepted')}
                          className="p-2 text-gray-400 hover:text-green-400 hover:bg-gray-800 rounded-lg transition-colors"
                          title="Accept Application"
                        >
                          <CheckCircle className="w-5 h-5" />
                        </button>
                        <button
                          onClick={() => handleStatusChange(application.id, 'rejected')}
                          className="p-2 text-gray-400 hover:text-red-400 hover:bg-gray-800 rounded-lg transition-colors"
                          title="Reject Application"
                        >
                          <XCircle className="w-5 h-5" />
                        </button>
                      </>
                    )}
                  </div>
                </div>

                {/* Cover Letter */}
                {application.cover_letter && (
                  <div className="mt-4 p-4 bg-gray-800 rounded-lg">
                    <h3 className="font-semibold mb-2">Cover Letter</h3>
                    <p className="text-gray-300 whitespace-pre-wrap">{application.cover_letter}</p>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
      
      {/* Application Details Modal */}
      {selectedApplication && (
        <div className="fixed inset-0 bg-black/75 flex items-center justify-center z-50 p-4">
          <div className="bg-gray-900 rounded-lg w-full max-w-2xl">
            <div className="p-6 border-b border-gray-800">
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-4">
                  <img
                    src={selectedApplication.applicant_avatar || `https://ui-avatars.com/api/?name=${encodeURIComponent(selectedApplication.applicant_name)}&background=random`}
                    alt={selectedApplication.applicant_name}
                    className="w-12 h-12 rounded-full"
                  />
                  <div>
                    <Link 
                      to={`/profile/${selectedApplication.applicant_username}`}
                      className="font-semibold hover:text-cyan-400 transition-colors"
                    >
                      {selectedApplication.applicant_name}
                    </Link>
                    <p className="text-gray-400">@{selectedApplication.applicant_username}</p>
                    <div className="flex items-center space-x-4 mt-2">
                      <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm ${
                        selectedApplication.status === 'unviewed'
                          ? 'bg-yellow-400/10 text-yellow-400'
                          : selectedApplication.status === 'pending'
                          ? 'bg-blue-400/10 text-blue-400'
                          : selectedApplication.status === 'on_hold'
                          ? 'bg-purple-400/10 text-purple-400'
                          : selectedApplication.status === 'accepted'
                          ? 'bg-green-400/10 text-green-400'
                          : 'bg-red-400/10 text-red-400'
                      }`}>
                        <Clock className="w-4 h-4 mr-1" />
                        {selectedApplication.status.charAt(0).toUpperCase() + selectedApplication.status.slice(1)}
                      </span>
                      <span className="text-sm text-gray-400">
                        Applied {format(new Date(selectedApplication.created_at), 'MMM d, yyyy')}
                      </span>
                    </div>
                  </div>
                </div>
                <button
                  onClick={() => setSelectedApplication(null)}
                  className="text-gray-400 hover:text-white transition-colors"
                >
                  <XCircle className="w-6 h-6" />
                </button>
              </div>
            </div>

            <div className="p-6 space-y-6">
              {/* Resume Download */}
              {selectedApplication.resume_url && (
                <div>
                  <h3 className="font-semibold mb-3">Resume</h3>
                  <a
                    href={selectedApplication.resume_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center space-x-2 bg-gray-800 text-white px-4 py-2 rounded-lg hover:bg-gray-700 transition-colors"
                  >
                    <Download className="w-5 h-5" />
                    <span>Download Resume</span>
                  </a>
                </div>
              )}

              {/* Cover Letter */}
              {selectedApplication.cover_letter && (
                <div>
                  <h3 className="font-semibold mb-3">Cover Letter</h3>
                  <div className="bg-gray-800 rounded-lg p-4">
                    <p className="text-gray-300 whitespace-pre-wrap">{selectedApplication.cover_letter}</p>
                  </div>
                  
                  {/* Application Details */}
                  <div className="mt-4 grid grid-cols-2 gap-4">
                    <div>
                      <h4 className="text-sm font-medium text-gray-400 mb-2">Contact</h4>
                      <div className="bg-gray-800 p-4 rounded-lg space-y-2">
                        <p className="text-sm">
                          <span className="text-gray-400">Email:</span>{' '}
                          <span className="text-white">{selectedApplication.applicant_email}</span>
                        </p>
                        <p className="text-sm">
                          <span className="text-gray-400">Phone:</span>{' '}
                          <span className="text-white">{selectedApplication.applicant_phone}</span>
                        </p>
                      </div>
                    </div>
                    
                    <div>
                      <h4 className="text-sm font-medium text-gray-400 mb-2">Experience</h4>
                      <div className="bg-gray-800 p-4 rounded-lg space-y-2">
                        <p className="text-sm">
                          <span className="text-gray-400">Current Role:</span>{' '}
                          <span className="text-white">{selectedApplication.applicant_position || 'N/A'}</span>
                        </p>
                        <p className="text-sm">
                          <span className="text-gray-400">Company:</span>{' '}
                          <span className="text-white">{selectedApplication.applicant_company || 'N/A'}</span>
                        </p>
                        <p className="text-sm">
                          <span className="text-gray-400">Experience:</span>{' '}
                          <span className="text-white">{selectedApplication.applicant_experience || 'N/A'}</span>
                        </p>
                      </div>
                    </div>
                    
                    <div>
                      <h4 className="text-sm font-medium text-gray-400 mb-2">Location</h4>
                      <div className="bg-gray-800 p-4 rounded-lg space-y-2">
                        <p className="text-sm">
                          <span className="text-gray-400">Current:</span>{' '}
                          <span className="text-white">{selectedApplication.applicant_location}</span>
                        </p>
                        {selectedApplication.can_relocate && (
                          <p className="text-sm text-cyan-400">Willing to relocate</p>
                        )}
                        {selectedApplication.preferred_locations?.length > 0 && (
                          <p className="text-sm">
                            <span className="text-gray-400">Preferred:</span>{' '}
                            <span className="text-white">{selectedApplication.preferred_locations.join(', ')}</span>
                          </p>
                        )}
                      </div>
                    </div>
                    
                    <div>
                      <h4 className="text-sm font-medium text-gray-400 mb-2">Compensation</h4>
                      <div className="bg-gray-800 p-4 rounded-lg space-y-2">
                        <p className="text-sm">
                          <span className="text-gray-400">Expected:</span>{' '}
                          <span className="text-white">{selectedApplication.applicant_salary}</span>
                          {selectedApplication.salary_negotiable && (
                            <span className="text-cyan-400 text-xs ml-2">(Negotiable)</span>
                          )}
                        </p>
                        <p className="text-sm">
                          <span className="text-gray-400">Notice Period:</span>{' '}
                          <span className="text-white">{selectedApplication.applicant_notice}</span>
                        </p>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* Application Actions */}
              <div className="flex space-x-3 pt-6 border-t border-gray-800">
                <button
                  onClick={() => handleStatusChange(selectedApplication.id, 'on_hold')}
                  className="flex-1 py-2 px-4 bg-purple-400/10 text-purple-400 rounded-lg hover:bg-purple-400/20 transition-colors"
                >
                  Put On Hold
                </button>
                <button
                  onClick={() => handleStatusChange(selectedApplication.id, 'accepted')}
                  className="flex-1 py-2 px-4 bg-green-400/10 text-green-400 rounded-lg hover:bg-green-400/20 transition-colors"
                >
                  Accept
                </button>
                <button
                  onClick={() => handleStatusChange(selectedApplication.id, 'rejected')}
                  className="flex-1 py-2 px-4 bg-red-400/10 text-red-400 rounded-lg hover:bg-red-400/20 transition-colors"
                >
                  Reject
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}