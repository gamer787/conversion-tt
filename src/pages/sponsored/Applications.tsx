import React, { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { ChevronLeft, Download, CheckCircle, XCircle, Clock } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { format } from 'date-fns';

interface Application {
  id: string;
  applicant_id: string;
  status: 'pending' | 'accepted' | 'rejected';
  portfolio_url: string | null;
  cover_letter: string;
  created_at: string;
  applicant: {
    username: string;
    display_name: string;
    avatar_url: string | null;
    badge?: {
      role: string;
    };
  };
}

interface SponsoredContent {
  id: string;
  title: string;
  description: string;
  budget: number;
  status: string;
}

export default function Applications() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [applications, setApplications] = useState<Application[]>([]);
  const [content, setContent] = useState<SponsoredContent | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedApplication, setSelectedApplication] = useState<Application | null>(null);

  useEffect(() => {
    loadApplications();
    loadContent();
  }, [id]);

  const loadContent = async () => {
    try {
      if (!id) return;
      
      const { data, error } = await supabase
        .from('sponsored_content')
        .select('*')
        .eq('id', id)
        .single();

      if (error) throw error;
      setContent(data);
    } catch (err) {
      console.error('Error loading content:', err);
    }
  };

  const loadApplications = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('sponsored_content_applications')
        .select(`
          *,
          applicant:applicant_id (
            username,
            display_name,
            avatar_url,
            badge:badge_subscriptions!left (
              role
            )
          )
        `)
        .eq('content_id', id)
        .order('created_at', { ascending: false });

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
      const { error } = await supabase
        .from('sponsored_content_applications')
        .update({ status: newStatus })
        .eq('id', applicationId);

      if (error) throw error;

      setApplications(prev => prev.map(app =>
        app.id === applicationId ? { ...app, status: newStatus } : app
      ));

      // If accepting, close the opportunity
      if (newStatus === 'accepted' && content) {
        await supabase
          .from('sponsored_content')
          .update({ status: 'completed' })
          .eq('id', content.id);

        setContent(prev => prev ? { ...prev, status: 'completed' } : null);
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
          onClick={() => navigate('/hub/sponsored')}
          className="p-2 hover:bg-gray-800 rounded-lg transition-colors"
        >
          <ChevronLeft className="w-6 h-6" />
        </button>
        <div>
          <h1 className="text-2xl font-bold">Applications</h1>
          {content && (
            <p className="text-sm text-gray-400 mt-1">
              {content.title} • Budget: ₹{content.budget.toLocaleString()}
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
          <h2 className="text-xl font-semibold mb-2">No applications yet</h2>
          <p className="text-gray-400">
            When creators apply for this opportunity, they'll appear here
          </p>
        </div>
      ) : (
        <div className="space-y-6">
          {applications.map((application) => (
            <div
              key={application.id}
              className="bg-gray-900 rounded-lg overflow-hidden"
            >
              <div className="p-6">
                <div className="flex items-start justify-between">
                  <div className="flex items-start space-x-4">
                    <Link to={`/profile/${application.applicant.username}`}>
                      <img
                        src={application.applicant.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(application.applicant.display_name)}&background=random`}
                        alt={application.applicant.display_name}
                        className="w-12 h-12 rounded-full"
                      />
                    </Link>
                    <div>
                      <Link 
                        to={`/profile/${application.applicant.username}`}
                        className="font-semibold hover:text-cyan-400 transition-colors"
                      >
                        {application.applicant.display_name}
                      </Link>
                      <p className="text-gray-400">@{application.applicant.username}</p>
                      {application.applicant.badge && (
                        <span className="inline-block bg-cyan-400/10 text-cyan-400 px-2 py-0.5 rounded text-xs mt-1">
                          {application.applicant.badge.role}
                        </span>
                      )}
                      <div className="flex items-center space-x-4 mt-2">
                        <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm ${
                          application.status === 'pending'
                            ? 'bg-yellow-400/10 text-yellow-400'
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
                    {application.portfolio_url && (
                      <a
                        href={application.portfolio_url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="p-2 text-gray-400 hover:text-cyan-400 hover:bg-gray-800 rounded-lg transition-colors"
                      >
                        <Download className="w-5 h-5" />
                      </a>
                    )}
                    {application.status === 'pending' && (
                      <>
                        <button
                          onClick={() => handleStatusChange(application.id, 'accepted')}
                          className="p-2 text-gray-400 hover:text-green-400 hover:bg-gray-800 rounded-lg transition-colors"
                        >
                          <CheckCircle className="w-5 h-5" />
                        </button>
                        <button
                          onClick={() => handleStatusChange(application.id, 'rejected')}
                          className="p-2 text-gray-400 hover:text-red-400 hover:bg-gray-800 rounded-lg transition-colors"
                        >
                          <XCircle className="w-5 h-5" />
                        </button>
                      </>
                    )}
                  </div>
                </div>

                {/* Cover Letter */}
                <div className="mt-4 p-4 bg-gray-800 rounded-lg">
                  <h3 className="font-semibold mb-2">Cover Letter</h3>
                  <p className="text-gray-300 whitespace-pre-wrap">{application.cover_letter}</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}