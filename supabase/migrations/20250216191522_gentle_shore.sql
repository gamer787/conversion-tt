-- Drop existing objects in the correct order
DROP TRIGGER IF EXISTS refresh_active_campaigns_trigger ON ad_campaigns;
DROP FUNCTION IF EXISTS refresh_active_campaigns CASCADE;
DROP MATERIALIZED VIEW IF EXISTS active_campaigns;
DROP FUNCTION IF EXISTS get_visible_ads;

-- Create optimized function with minimal computation
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
    -- Simplified distance calculation using law of cosines
    (
      6371 * acos(
        least(1.0, -- Prevent domain error in acos
          cos(radians(viewer_lat)) * 
          cos(radians(p.latitude)) * 
          cos(radians(p.longitude - viewer_lon)) +
          sin(radians(viewer_lat)) * 
          sin(radians(p.latitude))
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
    -- Rough bounding box filter
    AND p.latitude BETWEEN viewer_lat - (ac.radius_km / 111.0) AND viewer_lat + (ac.radius_km / 111.0)
    AND p.longitude BETWEEN viewer_lon - (ac.radius_km / (111.0 * cos(radians(viewer_lat)))) 
                           AND viewer_lon + (ac.radius_km / (111.0 * cos(radians(viewer_lat))))
  ORDER BY random()
  LIMIT 10;
$$;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_ad_campaigns_active_time 
ON ad_campaigns(status, start_time, end_time)
WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_profiles_location 
ON profiles(latitude, longitude)
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;