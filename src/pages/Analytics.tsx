import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { ChevronLeft, Eye, Users, Heart, MessageCircle, TrendingUp, Calendar, MapPin, Clock, Filter } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { format, subDays, startOfDay, endOfDay } from 'date-fns';
import { LineChart, Line, AreaChart, Area, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';

interface AnalyticsData {
  views: {
    total: number;
    vibes: number;
    bangers: number;
    trend: { date: string; count: number }[];
  };
  network: {
    total: number;
    newLast7Days: number;
    newLast30Days: number;
    acceptanceRate: number;
    active: number;
    inactive: number;
  };
  engagement: {
    profileVisits: number;
    interactionRate: number;
    comments: number;
    likes: number;
    shares: number;
  };
  reach: {
    direct: number;
    extended: number;
    locations: { location: string; count: number }[];
    peakTimes: { hour: number; count: number }[];
  };
  content: {
    topPosts: {
      id: string;
      type: string;
      views: number;
      likes: number;
      comments: number;
      created_at: string;
    }[];
    engagementByType: {
      type: string;
      rate: number;
    }[];
    bestDays: { day: string; engagement: number }[];
    retention: { duration: string; rate: number }[];
  };
}

const COLORS = ['#00E5FF', '#FF4081', '#7C4DFF', '#64FFDA', '#FFD740'];

function Analytics() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [dateRange, setDateRange] = useState<'7d' | '30d' | '90d'>('30d');
  const [data, setData] = useState<AnalyticsData | null>(null);

  useEffect(() => {
    loadAnalytics();
  }, [dateRange]);

  const loadAnalytics = async () => {
    try {
      setLoading(true);
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      // Get date range
      const endDate = endOfDay(new Date());
      const startDate = startOfDay(subDays(endDate, dateRange === '7d' ? 7 : dateRange === '30d' ? 30 : 90));

      // Get views data
      const [
        { data: viewsData },
        { data: networkData },
        { data: engagementData },
        { data: reachData },
        { data: contentData }
      ] = await Promise.all([
        // Views analytics
        supabase.rpc('get_views_analytics', {
          user_id: user.id,
          start_date: startDate.toISOString(),
          end_date: endDate.toISOString()
        }),
        // Network analytics
        supabase.rpc('get_network_analytics', {
          user_id: user.id,
          start_date: startDate.toISOString(),
          end_date: endDate.toISOString()
        }),
        // Engagement analytics
        supabase.rpc('get_engagement_analytics', {
          user_id: user.id,
          start_date: startDate.toISOString(),
          end_date: endDate.toISOString()
        }),
        // Reach analytics
        supabase.rpc('get_reach_analytics', {
          user_id: user.id,
          start_date: startDate.toISOString(),
          end_date: endDate.toISOString()
        }),
        // Content analytics
        supabase.rpc('get_content_analytics', {
          user_id: user.id,
          start_date: startDate.toISOString(),
          end_date: endDate.toISOString()
        })
      ]);

      setData({
        views: viewsData,
        network: networkData,
        engagement: engagementData,
        reach: reachData,
        content: contentData
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load analytics');
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

  if (error) {
    return (
      <div className="p-4 bg-red-400/10 text-red-400 rounded-lg">
        {error}
      </div>
    );
  }

  if (!data) return null;

  return (
    <div className="pb-20 pt-4">
      <div className="flex items-center justify-between mb-8">
        <div className="flex items-center space-x-3">
          <button
            onClick={() => navigate('/hub')}
            className="p-2 hover:bg-gray-800 rounded-lg transition-colors"
          >
            <ChevronLeft className="w-6 h-6" />
          </button>
          <div>
            <h1 className="text-2xl font-bold">Analytics</h1>
            <p className="text-sm text-gray-400">Track your social engagement</p>
          </div>
        </div>
        <div className="flex items-center space-x-2">
          <button
            onClick={() => setDateRange('7d')}
            className={`px-3 py-1 rounded-lg text-sm font-medium ${
              dateRange === '7d'
                ? 'bg-cyan-400 text-gray-900'
                : 'bg-gray-800 text-gray-400 hover:bg-gray-700'
            }`}
          >
            7D
          </button>
          <button
            onClick={() => setDateRange('30d')}
            className={`px-3 py-1 rounded-lg text-sm font-medium ${
              dateRange === '30d'
                ? 'bg-cyan-400 text-gray-900'
                : 'bg-gray-800 text-gray-400 hover:bg-gray-700'
            }`}
          >
            30D
          </button>
          <button
            onClick={() => setDateRange('90d')}
            className={`px-3 py-1 rounded-lg text-sm font-medium ${
              dateRange === '90d'
                ? 'bg-cyan-400 text-gray-900'
                : 'bg-gray-800 text-gray-400 hover:bg-gray-700'
            }`}
          >
            90D
          </button>
        </div>
      </div>

      <div className="space-y-6">
        {/* Views Overview */}
        <div className="bg-gray-900 rounded-lg p-6">
          <h2 className="text-lg font-semibold mb-6 flex items-center">
            <Eye className="w-5 h-5 mr-2 text-cyan-400" />
            Views Overview
          </h2>
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
            <div className="bg-gray-800 p-4 rounded-lg">
              <div className="text-3xl font-bold text-cyan-400">{data.views.total.toLocaleString()}</div>
              <div className="text-sm text-gray-400 mt-1">Total Views</div>
            </div>
            <div className="bg-gray-800 p-4 rounded-lg">
              <div className="text-3xl font-bold text-cyan-400">{data.views.vibes.toLocaleString()}</div>
              <div className="text-sm text-gray-400 mt-1">Vibe Views</div>
            </div>
            <div className="bg-gray-800 p-4 rounded-lg">
              <div className="text-3xl font-bold text-cyan-400">{data.views.bangers.toLocaleString()}</div>
              <div className="text-sm text-gray-400 mt-1">Banger Views</div>
            </div>
          </div>
          <div className="h-[300px]">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={data.views.trend}>
                <defs>
                  <linearGradient id="viewsGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#00E5FF" stopOpacity={0.1}/>
                    <stop offset="95%" stopColor="#00E5FF" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
                <XAxis 
                  dataKey="date" 
                  stroke="#9CA3AF"
                  tickFormatter={(date) => format(new Date(date), 'MMM d')}
                />
                <YAxis stroke="#9CA3AF" />
                <Tooltip
                  contentStyle={{
                    backgroundColor: '#1F2937',
                    border: '1px solid #374151',
                    borderRadius: '0.5rem'
                  }}
                  labelFormatter={(date) => format(new Date(date), 'MMM d, yyyy')}
                />
                <Area
                  type="monotone"
                  dataKey="count"
                  stroke="#00E5FF"
                  fillOpacity={1}
                  fill="url(#viewsGradient)"
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Network Growth */}
        <div className="bg-gray-900 rounded-lg p-6">
          <h2 className="text-lg font-semibold mb-6 flex items-center">
            <Users className="w-5 h-5 mr-2 text-purple-400" />
            Network Growth
          </h2>
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-6 mb-6">
            <div className="bg-gray-800 p-4 rounded-lg">
              <div className="text-3xl font-bold text-purple-400">{data.network.total.toLocaleString()}</div>
              <div className="text-sm text-gray-400 mt-1">Total Connections</div>
            </div>
            <div className="bg-gray-800 p-4 rounded-lg">
              <div className="text-3xl font-bold text-purple-400">
                +{data.network.newLast30Days.toLocaleString()}
              </div>
              <div className="text-sm text-gray-400 mt-1">New (30 Days)</div>
            </div>
            <div className="bg-gray-800 p-4 rounded-lg">
              <div className="text-3xl font-bold text-purple-400">
                {(data.network.acceptanceRate * 100).toFixed(1)}%
              </div>
              <div className="text-sm text-gray-400 mt-1">Acceptance Rate</div>
            </div>
            <div className="bg-gray-800 p-4 rounded-lg">
              <div className="text-3xl font-bold text-purple-400">
                {data.network.active.toLocaleString()}
              </div>
              <div className="text-sm text-gray-400 mt-1">Active Connections</div>
            </div>
          </div>
          <div className="h-[300px]">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={[
                    { name: 'Active', value: data.network.active },
                    { name: 'Inactive', value: data.network.inactive }
                  ]}
                  cx="50%"
                  cy="50%"
                  innerRadius={60}
                  outerRadius={80}
                  fill="#8884d8"
                  paddingAngle={5}
                  dataKey="value"
                >
                  {[
                    { name: 'Active', color: '#9333EA' },
                    { name: 'Inactive', color: '#4B5563' }
                  ].map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip
                  contentStyle={{
                    backgroundColor: '#1F2937',
                    border: '1px solid #374151',
                    borderRadius: '0.5rem'
                  }}
                />
              </PieChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Engagement Metrics */}
        <div className="bg-gray-900 rounded-lg p-6">
          <h2 className="text-lg font-semibold mb-6 flex items-center">
            <Heart className="w-5 h-5 mr-2 text-pink-400" />
            Engagement Metrics
          </h2>
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-6 mb-6">
            <div className="bg-gray-800 p-4 rounded-lg">
              <div className="text-3xl font-bold text-pink-400">
                {data.engagement.profileVisits.toLocaleString()}
              </div>
              <div className="text-sm text-gray-400 mt-1">Profile Visits</div>
            </div>
            <div className="bg-gray-800 p-4 rounded-lg">
              <div className="text-3xl font-bold text-pink-400">
                {(data.engagement.interactionRate * 100).toFixed(1)}%
              </div>
              <div className="text-sm text-gray-400 mt-1">Interaction Rate</div>
            </div>
            <div className="bg-gray-800 p-4 rounded-lg">
              <div className="text-3xl font-bold text-pink-400">
                {data.engagement.comments.toLocaleString()}
              </div>
              <div className="text-sm text-gray-400 mt-1">Comments</div>
            </div>
            <div className="bg-gray-800 p-4 rounded-lg">
              <div className="text-3xl font-bold text-pink-400">
                {data.engagement.likes.toLocaleString()}
              </div>
              <div className="text-sm text-gray-400 mt-1">Likes</div>
            </div>
          </div>
          <div className="h-[300px]">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={data.content.engagementByType}>
                <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
                <XAxis dataKey="type" stroke="#9CA3AF" />
                <YAxis stroke="#9CA3AF" />
                <Tooltip
                  contentStyle={{
                    backgroundColor: '#1F2937',
                    border: '1px solid #374151',
                    borderRadius: '0.5rem'
                  }}
                />
                <Bar dataKey="rate" fill="#EC4899" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Reach Analysis */}
        <div className="bg-gray-900 rounded-lg p-6">
          <h2 className="text-lg font-semibold mb-6 flex items-center">
            <TrendingUp className="w-5 h-5 mr-2 text-green-400" />
            Reach Analysis
          </h2>
          <div className="grid grid-cols-2 gap-6 mb-6">
            <div className="bg-gray-800 p-4 rounded-lg">
              <div className="text-3xl font-bold text-green-400">
                {data.reach.direct.toLocaleString()}
              </div>
              <div className="text-sm text-gray-400 mt-1">Direct Reach</div>
            </div>
            <div className="bg-gray-800 p-4 rounded-lg">
              <div className="text-3xl font-bold text-green-400">
                {data.reach.extended.toLocaleString()}
              </div>
              <div className="text-sm text-gray-400 mt-1">Extended Reach</div>
            </div>
          </div>
          <div className="h-[300px]">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={data.reach.peakTimes}>
                <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
                <XAxis 
                  dataKey="hour" 
                  stroke="#9CA3AF"
                  tickFormatter={(hour) => `${hour}:00`}
                />
                <YAxis stroke="#9CA3AF" />
                <Tooltip
                  contentStyle={{
                    backgroundColor: '#1F2937',
                    border: '1px solid #374151',
                    borderRadius: '0.5rem'
                  }}
                  labelFormatter={(hour) => `${hour}:00`}
                />
                <Line 
                  type="monotone" 
                  dataKey="count" 
                  stroke="#10B981" 
                  strokeWidth={2}
                  dot={{ fill: '#10B981' }}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Content Performance */}
        <div className="bg-gray-900 rounded-lg p-6">
          <h2 className="text-lg font-semibold mb-6 flex items-center">
            <MessageCircle className="w-5 h-5 mr-2 text-yellow-400" />
            Content Performance
          </h2>
          <div className="space-y-6">
            <div className="bg-gray-800 rounded-lg overflow-hidden">
              <div className="px-6 py-4 border-b border-gray-700">
                <h3 className="font-medium">Top Performing Posts</h3>
              </div>
              <div className="divide-y divide-gray-700">
                {data.content.topPosts.map((post) => (
                  <div key={post.id} className="px-6 py-4 flex items-center justify-between">
                    <div>
                      <div className="font-medium">{post.type}</div>
                      <div className="text-sm text-gray-400">
                        {format(new Date(post.created_at), 'MMM d, yyyy')}
                      </div>
                    </div>
                    <div className="flex items-center space-x-6">
                      <div className="text-center">
                        <div className="text-cyan-400 font-medium">
                          {post.views.toLocaleString()}
                        </div>
                        <div className="text-xs text-gray-400">Views</div>
                      </div>
                      <div className="text-center">
                        <div className="text-pink-400 font-medium">
                          {post.likes.toLocaleString()}
                        </div>
                        <div className="text-xs text-gray-400">Likes</div>
                      </div>
                      <div className="text-center">
                        <div className="text-purple-400 font-medium">
                          {post.comments.toLocaleString()}
                        </div>
                        <div className="text-xs text-gray-400">Comments</div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div className="bg-gray-800 p-6 rounded-lg">
                <h3 className="font-medium mb-4">Best Performing Days</h3>
                <div className="h-[200px]">
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={data.content.bestDays}>
                      <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
                      <XAxis dataKey="day" stroke="#9CA3AF" />
                      <YAxis stroke="#9CA3AF" />
                      <Tooltip
                        contentStyle={{
                          backgroundColor: '#1F2937',
                          border: '1px solid #374151',
                          borderRadius: '0.5rem'
                        }}
                      />
                      <Bar dataKey="engagement" fill="#FBBF24" />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              </div>

              <div className="bg-gray-800 p-6 rounded-lg">
                <h3 className="font-medium mb-4">Audience Retention</h3>
                <div className="h-[200px]">
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={data.content.retention}>
                      <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
                      <XAxis dataKey="duration" stroke="#9CA3AF" />
                      <YAxis stroke="#9CA3AF" />
                      <Tooltip
                        contentStyle={{
                          backgroundColor: '#1F2937',
                          border: '1px solid #374151',
                          borderRadius: '0.5rem'
                        }}
                      />
                      <Line 
                        type="monotone" 
                        dataKey="rate" 
                        stroke="#FBBF24" 
                        strokeWidth={2}
                        dot={{ fill: '#FBBF24' }}
                      />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default Analytics;