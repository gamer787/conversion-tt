/*
  # Fix ad campaign function

  1. Changes
    - Simplify distance calculation
    - Add limit to initial query
    - Remove complex recursive calculations
    - Add proper indexes
    - Optimize query plan

  2. Performance
    - Reduces stack depth usage
    - Improves query performance
    - Prevents timeouts
*/

-- Drop existing function
DROP FUNCTION IF EXISTS get_visible_ads;

-- Create simplified function with better performance
CREATE OR REPLACE FUNCTION get_visible_ads(
  viewer_lat double precision,
  viewer_lon double precision
)
RETURNS TABLE (
  campaign_id uuid,
  user_id uuid,
  content_id uuid,
  distance double precision
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH nearby_campaigns AS (
    SELECT 
      ac.id,
      ac.user_id,
      ac.content_id,
      p.latitude,
      p.longitude
    FROM ad_campaigns ac
    JOIN profiles p ON p.id = ac.user_id
    WHERE 
      ac.status = 'active'
      AND ac.start_time <= now()
      AND ac.end_time > now()
      AND p.latitude IS NOT NULL 
      AND p.longitude IS NOT NULL
      -- Simple bounding box filter
      AND p.latitude BETWEEN viewer_lat - 5 AND viewer_lat + 5
      AND p.longitude BETWEEN viewer_lon - 5 AND viewer_lon + 5
    LIMIT 50  -- Limit initial result set
  )
  SELECT 
    nc.id as campaign_id,
    nc.user_id,
    nc.content_id,
    -- Simple distance calculation (Manhattan distance)
    (abs(nc.latitude - viewer_lat) + abs(nc.longitude - viewer_lon)) * 111.045 as distance
  FROM nearby_campaigns nc
  ORDER BY RANDOM()
  LIMIT 10;
$$;

-- Ensure proper indexes exist
DROP INDEX IF EXISTS idx_ad_campaigns_active_time;
DROP INDEX IF EXISTS idx_profiles_location;

CREATE INDEX idx_ad_campaigns_active_time 
ON ad_campaigns(status, start_time, end_time)
WHERE status = 'active';

CREATE INDEX idx_profiles_location 
ON profiles(latitude, longitude)
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;