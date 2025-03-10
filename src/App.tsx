import React, { useEffect, useState, useCallback } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate, useNavigate } from 'react-router-dom';
import { supabase } from './lib/supabase';
import { Auth } from './components/Auth'; 
import { Navbar } from './components/Navbar.tsx';
import { TopNav } from './components/TopNav.tsx';
import HubProfile from './pages/HubProfile';
import CreatorFund from './pages/CreatorFund';
import UserApplications from './pages/jobs/UserApplications';
import CreateSponsored from './pages/sponsored/Create';
import ViewSponsored from './pages/sponsored/View';
import SponsoredDetails from './pages/sponsored/Details';
import Applications from './pages/sponsored/Applications';
import Home from './pages/Home';
import FindUsers from './pages/FindUsers';
import Upload from './pages/Upload';
import Notifications from './pages/Notifications';
import BadgeSelection from './pages/BadgeSelection';
import BadgeInfo from './pages/BadgeInfo';
import CreateJob from './pages/jobs/CreateJob';
import JobInfo from './pages/jobs/JobInfo';
import ViewJobs from './pages/jobs/ViewJobs';
import JobDetails from './pages/jobs/JobDetails';
import JobApplications from './pages/jobs/JobApplications';
import Ads from './pages/Ads';
import Analytics from './pages/Analytics';
import Profile from './pages/Profile';
import Hub from './pages/Hub';
import Settings from './pages/Settings';

function App() {
  const [session, setSession] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Get initial session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      setLoading(false);
    }).catch((err) => {
      console.error('Error getting session:', err);
      setLoading(false);
      setSession(null);
    });

    // Listen for auth changes
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (event, session) => {
      setSession(session);
    });

    return () => subscription.unsubscribe();
  }, []);

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-950 flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-cyan-400"></div>
      </div>
    );
  }

  if (!session) {
    return <Auth />;
  }

  return (
    <Router>
      <div className="min-h-screen bg-gray-950 text-white">
        <TopNav />
        <div className="max-w-7xl mx-auto px-4">
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/find" element={<FindUsers />} />
            <Route path="/upload" element={<Upload />} />
            <Route path="/notifications" element={<Notifications />} />
            <Route path="/hub/badge/selection" element={<BadgeSelection />} />
            <Route path="/hub/badge/info" element={<BadgeInfo />} />
            <Route path="/hub/jobs/create" element={<CreateJob />} />
            <Route path="/hub/profile" element={<HubProfile />} />
            <Route path="/hub/fund/info" element={<CreatorFund />} />
            <Route path="/hub/jobs/create/:id" element={<CreateJob />} />
            <Route path="/hub/jobs/info" element={<JobInfo />} />
            <Route path="/hub/jobs" element={<ViewJobs />} />
            <Route path="/hub/jobs/applications" element={<UserApplications />} />
            <Route path="/hub/jobs/:jobId/applications" element={<JobApplications />} />
            <Route path="/hub/jobs/:id" element={<JobDetails />} />
            <Route path="/hub/sponsored/create" element={<CreateSponsored />} />
            <Route path="/hub/sponsored" element={<ViewSponsored />} />
            <Route path="/hub/sponsored/:id" element={<SponsoredDetails />} />
            <Route path="/hub/sponsored/:id/applications" element={<Applications />} />
            <Route path="/ads" element={<Ads />} />
            <Route path="/hub/analytics" element={<Analytics />} />
            <Route path="/profile" element={<Profile />} />
            <Route path="/profile/:username" element={<Profile />} />
            <Route path="/hub" element={<Hub />} />
            <Route path="/settings" element={<Settings />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </div>
        <Navbar />
      </div>
    </Router>
  );
}

export default App;