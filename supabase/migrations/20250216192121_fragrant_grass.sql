-- Drop existing function
DROP FUNCTION IF EXISTS get_visible_ads;

-- Create ultra-simplified function with minimal computation
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
  WITH bounds AS (
    SELECT 
      viewer_lat - 5 as min_lat,
      viewer_lat + 5 as max_lat,
      viewer_lon - 5 as min_lon,
      viewer_lon + 5 as max_lon
  )
  SELECT 
    ac.id as campaign_id,
    ac.user_id,
    ac.content_id,
    -- Ultra-simplified distance calculation
    111.045 * sqrt(
      (p.latitude - viewer_lat)^2 + 
      ((p.longitude - viewer_lon) * cos(radians(viewer_lat)))^2
    ) as distance
  FROM ad_campaigns ac
  JOIN profiles p ON p.id = ac.user_id
  CROSS JOIN bounds b
  WHERE 
    ac.status = 'active'
    AND ac.start_time <= now()
    AND ac.end_time > now()
    AND p.latitude IS NOT NULL
    AND p.longitude IS NOT NULL
    AND p.latitude BETWEEN b.min_lat AND b.max_lat
    AND p.longitude BETWEEN b.min_lon AND b.max_lon
  LIMIT 5;
$$;

-- Drop and recreate indexes for better performance
DROP INDEX IF EXISTS idx_ad_campaigns_active_time;
DROP INDEX IF EXISTS idx_profiles_location;

CREATE INDEX idx_ad_campaigns_active_time 
ON ad_campaigns(status, start_time, end_time)
WHERE status = 'active';

CREATE INDEX idx_profiles_location 
ON profiles(latitude, longitude)
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;