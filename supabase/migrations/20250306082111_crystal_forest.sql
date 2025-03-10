/*
  # Analytics System Migration

  This migration creates the analytics tracking system including tables and functions.

  1. New Tables
    - post_views: Track content views
    - profile_views: Track profile visits
    - view_durations: Track content view duration

  2. New Functions
    - get_views_analytics: View count analytics
    - get_network_analytics: Network growth metrics
    - get_engagement_analytics: User engagement stats
    - get_reach_analytics: Content reach analysis
    - get_content_analytics: Content performance metrics

  3. Security
    - RLS policies for all tables
    - Execute permissions for functions
*/

-- Create post_views table
CREATE TABLE IF NOT EXISTS post_views (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid REFERENCES posts(id) ON DELETE CASCADE,
  viewer_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  view_time timestamp with time zone DEFAULT now(),
  viewer_location text,
  direct_connection boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now()
);

-- Create profile_views table
CREATE TABLE IF NOT EXISTS profile_views (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  viewer_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamp with time zone DEFAULT now()
);

-- Create view_durations table
CREATE TABLE IF NOT EXISTS view_durations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid REFERENCES posts(id) ON DELETE CASCADE,
  viewer_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  watch_duration integer NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

-- Enable RLS
ALTER TABLE post_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE profile_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE view_durations ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own post views"
  ON post_views
  FOR SELECT
  TO authenticated
  USING (post_id IN (SELECT id FROM posts WHERE user_id = auth.uid()));

CREATE POLICY "Users can view their own profile views"
  ON profile_views
  FOR SELECT
  TO authenticated
  USING (profile_id = auth.uid());

CREATE POLICY "Users can view their own view durations"
  ON view_durations
  FOR SELECT
  TO authenticated
  USING (post_id IN (SELECT id FROM posts WHERE user_id = auth.uid()));

-- Views Analytics Function
CREATE OR REPLACE FUNCTION get_views_analytics(
  user_id UUID,
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ
) RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  WITH daily_views AS (
    SELECT 
      date_trunc('day', created_at) AS date,
      COUNT(*) AS count
    FROM post_views
    WHERE post_id IN (SELECT id FROM posts WHERE user_id = $1)
    AND created_at BETWEEN $2 AND $3
    GROUP BY date_trunc('day', created_at)
  ),
  total_views AS (
    SELECT 
      COUNT(*) AS total,
      COUNT(*) FILTER (WHERE p.type = 'vibe') AS vibes,
      COUNT(*) FILTER (WHERE p.type = 'banger') AS bangers
    FROM post_views v
    JOIN posts p ON p.id = v.post_id
    WHERE p.user_id = $1
    AND v.created_at BETWEEN $2 AND $3
  )
  SELECT json_build_object(
    'total', COALESCE((SELECT total FROM total_views), 0),
    'vibes', COALESCE((SELECT vibes FROM total_views), 0),
    'bangers', COALESCE((SELECT bangers FROM total_views), 0),
    'trend', COALESCE((
      SELECT json_agg(json_build_object(
        'date', date,
        'count', count
      ) ORDER BY date)
      FROM daily_views
    ), '[]'::json)
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Network Analytics Function
CREATE OR REPLACE FUNCTION get_network_analytics(
  user_id UUID,
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ
) RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  WITH network_stats AS (
    SELECT
      COUNT(*) FILTER (WHERE status = 'accepted') AS total_connections,
      COUNT(*) FILTER (WHERE status = 'accepted' AND created_at >= $2) AS new_connections,
      CAST(COUNT(*) FILTER (WHERE status = 'accepted') AS numeric) /
        NULLIF(COUNT(*) FILTER (WHERE status IN ('accepted', 'rejected')), 0) AS acceptance_rate,
      COUNT(*) FILTER (WHERE status = 'accepted' AND updated_at >= NOW() - INTERVAL '30 days') AS active_connections,
      COUNT(*) FILTER (WHERE status = 'accepted' AND updated_at < NOW() - INTERVAL '30 days') AS inactive_connections
    FROM friend_requests
    WHERE receiver_id = $1 OR sender_id = $1
  )
  SELECT json_build_object(
    'total', COALESCE((SELECT total_connections FROM network_stats), 0),
    'newLast7Days', COALESCE((SELECT new_connections FROM network_stats), 0),
    'newLast30Days', COALESCE((SELECT new_connections FROM network_stats), 0),
    'acceptanceRate', COALESCE((SELECT acceptance_rate FROM network_stats), 0),
    'active', COALESCE((SELECT active_connections FROM network_stats), 0),
    'inactive', COALESCE((SELECT inactive_connections FROM network_stats), 0)
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Engagement Analytics Function
CREATE OR REPLACE FUNCTION get_engagement_analytics(
  user_id UUID,
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ
) RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  WITH engagement_stats AS (
    SELECT
      COUNT(DISTINCT pv.viewer_id) AS profile_visits,
      CAST(COUNT(*) FILTER (WHERE i.type IN ('like', 'comment')) AS numeric) /
        NULLIF(COUNT(DISTINCT p.id), 0) AS interaction_rate,
      COUNT(*) FILTER (WHERE i.type = 'comment') AS comments,
      COUNT(*) FILTER (WHERE i.type = 'like') AS likes,
      COUNT(*) FILTER (WHERE i.type = 'share') AS shares
    FROM posts p
    LEFT JOIN interactions i ON i.post_id = p.id
    LEFT JOIN profile_views pv ON pv.profile_id = p.user_id
    WHERE p.user_id = $1
    AND p.created_at BETWEEN $2 AND $3
  )
  SELECT json_build_object(
    'profileVisits', COALESCE((SELECT profile_visits FROM engagement_stats), 0),
    'interactionRate', COALESCE((SELECT interaction_rate FROM engagement_stats), 0),
    'comments', COALESCE((SELECT comments FROM engagement_stats), 0),
    'likes', COALESCE((SELECT likes FROM engagement_stats), 0),
    'shares', COALESCE((SELECT shares FROM engagement_stats), 0)
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Reach Analytics Function
CREATE OR REPLACE FUNCTION get_reach_analytics(
  user_id UUID,
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ
) RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  WITH reach_stats AS (
    SELECT
      COUNT(DISTINCT viewer_id) FILTER (WHERE direct_connection = true) AS direct_reach,
      COUNT(DISTINCT viewer_id) FILTER (WHERE direct_connection = false) AS extended_reach,
      json_agg(DISTINCT jsonb_build_object(
        'location', viewer_location,
        'count', COUNT(*) OVER (PARTITION BY viewer_location)
      )) AS locations,
      json_agg(DISTINCT jsonb_build_object(
        'hour', EXTRACT(HOUR FROM view_time),
        'count', COUNT(*) OVER (PARTITION BY EXTRACT(HOUR FROM view_time))
      )) AS peak_times
    FROM post_views pv
    JOIN posts p ON p.id = pv.post_id
    WHERE p.user_id = $1
    AND pv.created_at BETWEEN $2 AND $3
  )
  SELECT json_build_object(
    'direct', COALESCE((SELECT direct_reach FROM reach_stats), 0),
    'extended', COALESCE((SELECT extended_reach FROM reach_stats), 0),
    'locations', COALESCE((SELECT locations FROM reach_stats), '[]'::json),
    'peakTimes', COALESCE((SELECT peak_times FROM reach_stats), '[]'::json)
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Content Analytics Function
CREATE OR REPLACE FUNCTION get_content_analytics(
  user_id UUID,
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ
) RETURNS JSON AS $$
DECLARE
  result JSON;
  top_posts JSON;
BEGIN
  -- Get top posts
  WITH post_stats AS (
    SELECT 
      p.id,
      p.type,
      COUNT(DISTINCT pv.viewer_id) as views,
      COUNT(DISTINCT CASE WHEN i.type = 'like' THEN i.user_id END) as likes,
      COUNT(DISTINCT CASE WHEN i.type = 'comment' THEN i.user_id END) as comments,
      p.created_at
    FROM posts p
    LEFT JOIN post_views pv ON pv.post_id = p.id
    LEFT JOIN interactions i ON i.post_id = p.id
    WHERE p.user_id = $1
    AND p.created_at BETWEEN $2 AND $3
    GROUP BY p.id, p.type
    ORDER BY views DESC
    LIMIT 5
  )
  SELECT json_agg(
    json_build_object(
      'id', id,
      'type', type,
      'views', views,
      'likes', likes,
      'comments', comments,
      'created_at', created_at
    )
  ) INTO top_posts
  FROM post_stats;

  -- Get other analytics
  WITH content_stats AS (
    SELECT
      json_agg(DISTINCT jsonb_build_object(
        'type', p.type,
        'rate', CAST(COUNT(i.*) AS numeric) / NULLIF(COUNT(DISTINCT p.id), 0)
      )) AS engagement_by_type,
      json_agg(DISTINCT jsonb_build_object(
        'day', TO_CHAR(p.created_at, 'Day'),
        'engagement', COUNT(i.*)
      )) AS best_days,
      json_agg(DISTINCT jsonb_build_object(
        'duration', 
        CASE 
          WHEN vd.watch_duration < 30 THEN '0-30s'
          WHEN vd.watch_duration < 60 THEN '30-60s'
          WHEN vd.watch_duration < 120 THEN '1-2m'
          ELSE '2m+'
        END,
        'rate', CAST(COUNT(*) AS numeric) / NULLIF(SUM(COUNT(*)) OVER (), 0)
      )) AS retention
    FROM posts p
    LEFT JOIN view_durations vd ON vd.post_id = p.id
    LEFT JOIN interactions i ON i.post_id = p.id
    WHERE p.user_id = $1
    AND p.created_at BETWEEN $2 AND $3
    GROUP BY p.type
  )
  SELECT json_build_object(
    'topPosts', COALESCE(top_posts, '[]'::json),
    'engagementByType', COALESCE((SELECT engagement_by_type FROM content_stats), '[]'::json),
    'bestDays', COALESCE((SELECT best_days FROM content_stats), '[]'::json),
    'retention', COALESCE((SELECT retention FROM content_stats), '[]'::json)
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_views_analytics TO authenticated;
GRANT EXECUTE ON FUNCTION get_network_analytics TO authenticated;
GRANT EXECUTE ON FUNCTION get_engagement_analytics TO authenticated;
GRANT EXECUTE ON FUNCTION get_reach_analytics TO authenticated;
GRANT EXECUTE ON FUNCTION get_content_analytics TO authenticated;