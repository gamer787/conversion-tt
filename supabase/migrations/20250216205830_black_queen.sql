-- Drop existing function
DROP FUNCTION IF EXISTS get_visible_ads(double precision, double precision);

-- Create optimized function for getting visible ads with social features
CREATE OR REPLACE FUNCTION get_visible_ads(
  viewer_lat double precision,
  viewer_lon double precision
)
RETURNS TABLE (
  campaign_id uuid,
  user_id uuid,
  content_id uuid,
  distance double precision,
  username text,
  display_name text,
  avatar_url text,
  account_type text,
  content_type text,
  content_url text,
  caption text,
  likes_count bigint,
  comments_count bigint,
  created_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH active_campaigns AS (
    SELECT 
      ac.id,
      ac.user_id,
      ac.content_id,
      p.latitude,
      p.longitude,
      p.username,
      p.display_name,
      p.avatar_url,
      p.account_type,
      po.type as content_type,
      po.content_url,
      po.caption,
      po.created_at
    FROM ad_campaigns ac
    JOIN profiles p ON p.id = ac.user_id
    JOIN posts po ON po.id = ac.content_id
    WHERE 
      ac.status = 'active'
      AND ac.start_time <= now()
      AND ac.end_time > now()
      AND p.latitude IS NOT NULL 
      AND p.longitude IS NOT NULL
      AND p.latitude BETWEEN viewer_lat - 0.5 AND viewer_lat + 0.5
      AND p.longitude BETWEEN viewer_lon - 0.5 AND viewer_lon + 0.5
    LIMIT 50
  ),
  campaigns_with_distance AS (
    SELECT 
      ac.id,
      ac.user_id,
      ac.content_id,
      ac.username,
      ac.display_name,
      ac.avatar_url,
      ac.account_type,
      ac.content_type,
      ac.content_url,
      ac.caption,
      ac.created_at,
      ROUND(
        CAST(
          111.045 * sqrt(
            power(ac.latitude - viewer_lat, 2) + 
            power(ac.longitude - viewer_lon, 2)
          ) AS numeric
        ),
        3
      ) as distance
    FROM active_campaigns ac
  ),
  interaction_counts AS (
    SELECT 
      post_id,
      COUNT(*) FILTER (WHERE type = 'like') as likes_count,
      COUNT(*) FILTER (WHERE type = 'comment') as comments_count
    FROM interactions
    WHERE post_id IN (SELECT content_id FROM campaigns_with_distance)
    GROUP BY post_id
  )
  SELECT 
    cd.id as campaign_id,
    cd.user_id,
    cd.content_id,
    cd.distance,
    cd.username,
    cd.display_name,
    cd.avatar_url,
    cd.account_type,
    cd.content_type,
    cd.content_url,
    cd.caption,
    COALESCE(ic.likes_count, 0) as likes_count,
    COALESCE(ic.comments_count, 0) as comments_count,
    cd.created_at
  FROM campaigns_with_distance cd
  LEFT JOIN interaction_counts ic ON ic.post_id = cd.content_id
  ORDER BY random()
  LIMIT 3;
$$;