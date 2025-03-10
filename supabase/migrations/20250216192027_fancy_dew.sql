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
  SELECT 
    ac.id as campaign_id,
    ac.user_id,
    ac.content_id,
    -- Simple distance calculation using degrees
    111.045 * sqrt(
      power(p.latitude - viewer_lat, 2) + 
      power((p.longitude - viewer_lon) * cos(radians(viewer_lat)), 2)
    ) as distance
  FROM ad_campaigns ac
  JOIN profiles p ON p.id = ac.user_id
  WHERE 
    ac.status = 'active'
    AND ac.start_time <= now()
    AND ac.end_time > now()
    AND p.latitude IS NOT NULL
    AND p.longitude IS NOT NULL
    -- Pre-filter using bounding box
    AND p.latitude BETWEEN viewer_lat - 5 AND viewer_lat + 5
    AND p.longitude BETWEEN viewer_lon - 5 AND viewer_lon + 5
  ORDER BY random()
  LIMIT 5;
$$;

-- Create or replace indexes for better performance
DROP INDEX IF EXISTS idx_ad_campaigns_active_time;
DROP INDEX IF EXISTS idx_profiles_location;

CREATE INDEX idx_ad_campaigns_active_time 
ON ad_campaigns(status, start_time, end_time)
WHERE status = 'active';

CREATE INDEX idx_profiles_location 
ON profiles(latitude, longitude)
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;