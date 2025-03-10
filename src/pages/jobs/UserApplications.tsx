import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { ChevronLeft, Building2, Download, Clock, Eye } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { format } from 'date-fns';

interface Application {
  id: uuid;
  job_id: uuid;
  status: 'unviewed' | 'pending' | 'accepted' | 'rejected';
  created_at: string;
  updated_at: string;
  resume_url: string;
  cover_letter: string;
  job_title: string;
  company_name: string;
  company_logo: string;
}

export default function UserApplications() {
  const navigate = useNavigate();
  const [applications, setApplications] = useState<Application[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);

  useEffect(() => {
    supabase.auth.getUser().then(({ data: { user } }) => {
      setCurrentUserId(user?.id || null);
      if (user) {
        loadApplications(user.id);
      }
    });
  }, []);

  const loadApplications = async (userId: string) => {
    try {
      setLoading(true);
      const { data, error } = await supabase.rpc('get_user_applications', { applicant_id: userId });

      if (error) throw error;
      setApplications(data || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load applications');
    } finally {
      setLoading(false);
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
        <h1 className="text-2xl font-bold">My Applications</h1>
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
            Start applying for jobs to see your applications here
          </p>
        </div>
      ) : (
        <div className="space-y-6">
          {applications.map((application) => (
            <div 
              key={application.id}
              className="bg-gray-900 rounded-lg overflow-hidden border border-gray-800"
            >
              <div className="p-6">
                <div className="flex items-start justify-between">
                  <div className="flex items-start space-x-4">
                    <div className="w-16 h-16 bg-white rounded-lg p-2 flex items-center justify-center border border-gray-200">
                      {application.company_logo ? (
                        <img
                          src={application.company_logo}
                          alt={application.company_name}
                          className="w-full h-full object-contain"
                        />
                      ) : (
                        <Building2 className="w-8 h-8 text-gray-500" />
                      )}
                    </div>
                    <div>
                      <h2 className="text-xl font-semibold">
                        {application.job_title}
                        {application.current_role && <span className="text-gray-400 text-sm ml-2">({application.current_role})</span>}
                      </h2>
                      <p className="text-gray-400">{application.company_name}</p>
                      <div className="flex items-center space-x-4 mt-2">
                        <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm ${
                          application.status === 'unviewed'
                            ? 'bg-yellow-400/10 text-yellow-400'
                            : application.status === 'pending'
                            ? 'bg-blue-400/10 text-blue-400'
                            : application.status === 'accepted'
                            ? 'bg-green-400/10 text-green-400'
                            : 'bg-red-400/10 text-red-400'
                        }`}>
                          <Clock className="w-4 h-4 mr-1" />
                          {application.status.charAt(0).toUpperCase() + application.status.slice(1)}
                        </span>
                        <span className="text-sm text-gray-400">
                          Applied {format(new Date(application.created_at), 'MMM d, yyyy')} •
                          {application.expected_salary && <span className="ml-2">Expected: {application.expected_salary}</span>}
                          {application.notice_period && <span className="ml-2">• Notice: {application.notice_period}</span>}
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
                    <button
                      onClick={() => navigate(`/hub/jobs/${application.job_id}`)}
                      className="p-2 text-gray-400 hover:text-cyan-400 hover:bg-gray-800 rounded-lg transition-colors"
                      title="View Job"
                    >
                      <Eye className="w-5 h-5" />
                    </button>
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
    </div>
  );
}