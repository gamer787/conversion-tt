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
  WITH active_campaigns AS (
    -- First filter active campaigns
    SELECT 
      ac.id,
      ac.user_id,
      ac.content_id,
      ac.radius_km,
      p.latitude,
      p.longitude
    FROM ad_campaigns ac
    JOIN profiles p ON p.id = ac.user_id
    WHERE 
      ac.status = 'active'
      AND ac.start_time <= now()
      AND ac.end_time > now()
      AND ac.is_test = false
      AND p.latitude IS NOT NULL
      AND p.longitude IS NOT NULL
      -- Rough bounding box filter
      AND p.latitude BETWEEN viewer_lat - 5 AND viewer_lat + 5
      AND p.longitude BETWEEN viewer_lon - 5 AND viewer_lon + 5
  )
  SELECT 
    ac.id as campaign_id,
    ac.user_id,
    ac.content_id,
    -- Simplified distance calculation
    111.111 * 
    DEGREES(
      ACOS(
        LEAST(1.0, COS(RADIANS(viewer_lat)) * 
        COS(RADIANS(ac.latitude)) * 
        COS(RADIANS(ac.longitude - viewer_lon)) +
        SIN(RADIANS(viewer_lat)) * 
        SIN(RADIANS(ac.latitude)))
    )
  ) as distance
  FROM active_campaigns ac
  WHERE 111.111 * 
    DEGREES(
      ACOS(
        LEAST(1.0, COS(RADIANS(viewer_lat)) * 
        COS(RADIANS(ac.latitude)) * 
        COS(RADIANS(ac.longitude - viewer_lon)) +
        SIN(RADIANS(viewer_lat)) * 
        SIN(RADIANS(ac.latitude)))
    )
  ) <= ac.radius_km
  ORDER BY RANDOM()
  LIMIT 10;
$$;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_ad_campaigns_active_time 
ON ad_campaigns(status, start_time, end_time)
WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_profiles_location 
ON profiles(latitude, longitude)
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;