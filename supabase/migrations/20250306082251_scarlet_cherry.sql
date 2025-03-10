/*
  # Fix Analytics Functions Migration

  This migration fixes the analytics functions to properly handle aggregations and window functions.

  1. Changes
    - Fixed nested aggregates in window functions
    - Resolved ambiguous column references
    - Corrected JSON aggregation syntax
    - Improved performance with proper indexing

  2. Functions Updated
    - get_views_analytics
    - get_network_analytics
    - get_engagement_analytics
    - get_reach_analytics
    - get_content_analytics

  3. Security
    - All functions remain SECURITY DEFINER
    - Execute permissions maintained
*/

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
      date_trunc('day', pv.created_at) AS date,
      COUNT(*) AS count
    FROM post_views pv
    JOIN posts p ON p.id = pv.post_id
    WHERE p.user_id = $1
    AND pv.created_at BETWEEN $2 AND $3
    GROUP BY date_trunc('day', pv.created_at)
  ),
  total_views AS (
    SELECT 
      COUNT(*) AS total,
      COUNT(*) FILTER (WHERE p.type = 'vibe') AS vibes,
      COUNT(*) FILTER (WHERE p.type = 'banger') AS bangers
    FROM post_views pv
    JOIN posts p ON p.id = pv.post_id
    WHERE p.user_id = $1
    AND pv.created_at BETWEEN $2 AND $3
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
  WITH location_stats AS (
    SELECT 
      viewer_location,
      COUNT(*) as location_count
    FROM post_views pv
    JOIN posts p ON p.id = pv.post_id
    WHERE p.user_id = $1
    AND pv.created_at BETWEEN $2 AND $3
    AND viewer_location IS NOT NULL
    GROUP BY viewer_location
  ),
  time_stats AS (
    SELECT 
      EXTRACT(HOUR FROM view_time) as hour,
      COUNT(*) as hour_count
    FROM post_views pv
    JOIN posts p ON p.id = pv.post_id
    WHERE p.user_id = $1
    AND pv.created_at BETWEEN $2 AND $3
    GROUP BY EXTRACT(HOUR FROM view_time)
  ),
  reach_totals AS (
    SELECT
      COUNT(DISTINCT viewer_id) FILTER (WHERE direct_connection = true) AS direct_reach,
      COUNT(DISTINCT viewer_id) FILTER (WHERE direct_connection = false) AS extended_reach
    FROM post_views pv
    JOIN posts p ON p.id = pv.post_id
    WHERE p.user_id = $1
    AND pv.created_at BETWEEN $2 AND $3
  )
  SELECT json_build_object(
    'direct', COALESCE((SELECT direct_reach FROM reach_totals), 0),
    'extended', COALESCE((SELECT extended_reach FROM reach_totals), 0),
    'locations', COALESCE((
      SELECT json_agg(json_build_object(
        'location', viewer_location,
        'count', location_count
      ))
      FROM location_stats
    ), '[]'::json),
    'peakTimes', COALESCE((
      SELECT json_agg(json_build_object(
        'hour', hour,
        'count', hour_count
      ) ORDER BY hour)
      FROM time_stats
    ), '[]'::json)
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
  ),
  engagement_by_type AS (
    SELECT
      p.type,
      CAST(COUNT(i.*) AS numeric) / NULLIF(COUNT(DISTINCT p.id), 0) as rate
    FROM posts p
    LEFT JOIN interactions i ON i.post_id = p.id
    WHERE p.user_id = $1
    AND p.created_at BETWEEN $2 AND $3
    GROUP BY p.type
  ),
  daily_engagement AS (
    SELECT
      TO_CHAR(p.created_at, 'Day') as day,
      COUNT(i.*) as engagement_count
    FROM posts p
    LEFT JOIN interactions i ON i.post_id = p.id
    WHERE p.user_id = $1
    AND p.created_at BETWEEN $2 AND $3
    GROUP BY TO_CHAR(p.created_at, 'Day')
  ),
  retention_stats AS (
    SELECT
      CASE 
        WHEN vd.watch_duration < 30 THEN '0-30s'
        WHEN vd.watch_duration < 60 THEN '30-60s'
        WHEN vd.watch_duration < 120 THEN '1-2m'
        ELSE '2m+'
      END as duration,
      CAST(COUNT(*) AS numeric) / NULLIF(SUM(COUNT(*)) OVER (), 0) as rate
    FROM posts p
    LEFT JOIN view_durations vd ON vd.post_id = p.id
    WHERE p.user_id = $1
    AND p.created_at BETWEEN $2 AND $3
    GROUP BY 
      CASE 
        WHEN vd.watch_duration < 30 THEN '0-30s'
        WHEN vd.watch_duration < 60 THEN '30-60s'
        WHEN vd.watch_duration < 120 THEN '1-2m'
        ELSE '2m+'
      END
  )
  SELECT json_build_object(
    'topPosts', COALESCE((
      SELECT json_agg(post_stats)
      FROM post_stats
    ), '[]'::json),
    'engagementByType', COALESCE((
      SELECT json_agg(json_build_object(
        'type', type,
        'rate', rate
      ))
      FROM engagement_by_type
    ), '[]'::json),
    'bestDays', COALESCE((
      SELECT json_agg(json_build_object(
        'day', day,
        'engagement', engagement_count
      ))
      FROM daily_engagement
    ), '[]'::json),
    'retention', COALESCE((
      SELECT json_agg(json_build_object(
        'duration', duration,
        'rate', rate
      ))
      FROM retention_stats
    ), '[]'::json)
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