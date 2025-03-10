/*
  # Enhance Ads Display

  1. Changes
    - Add user information to get_visible_ads function
    - Add interaction support
    
  2. Security
    - Maintain RLS policies
*/

-- Drop existing function
DROP FUNCTION IF EXISTS get_visible_ads;

-- Create enhanced function with user information
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
  likes_count bigint,
  comments_count bigint
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
      p.account_type
    FROM ad_campaigns ac
    JOIN profiles p ON p.id = ac.user_id
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
    COALESCE(ic.likes_count, 0) as likes_count,
    COALESCE(ic.comments_count, 0) as comments_count
  FROM campaigns_with_distance cd
  LEFT JOIN interaction_counts ic ON ic.post_id = cd.content_id
  ORDER BY random()
  LIMIT 3;
$$;