-- Drop existing function
DROP FUNCTION IF EXISTS get_visible_ads;

-- Create optimized function with simplified distance calculation
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
  SELECT 
    ac.id as campaign_id,
    ac.user_id,
    ac.content_id,
    -- Simplified distance calculation (in km)
    (
      6371 * 2 * asin(
        sqrt(
          sin(radians(p.latitude - viewer_lat) / 2)^2 +
          cos(radians(viewer_lat)) *
          cos(radians(p.latitude)) *
          sin(radians(p.longitude - viewer_lon) / 2)^2
        )
      )
    ) as distance
  FROM ad_campaigns ac
  JOIN profiles p ON p.id = ac.user_id
  WHERE 
    ac.status = 'active'
    AND ac.start_time <= now()
    AND ac.end_time > now()
    AND p.latitude IS NOT NULL
    AND p.longitude IS NOT NULL
    -- Rough bounding box filter for initial filtering
    AND p.latitude BETWEEN viewer_lat - 5 AND viewer_lat + 5
    AND p.longitude BETWEEN viewer_lon - 5 AND viewer_lon + 5
  ORDER BY random()
  LIMIT 10;
$$;

-- Create index to improve performance
CREATE INDEX IF NOT EXISTS idx_ad_campaigns_active_time 
ON ad_campaigns(status, start_time, end_time)
WHERE status = 'active';

-- Create index for location-based queries
CREATE INDEX IF NOT EXISTS idx_profiles_location 
ON profiles(latitude, longitude)
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;