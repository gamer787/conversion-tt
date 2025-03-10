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
  -- Get active campaigns with minimal computation
  WITH active_campaigns AS (
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
      -- Pre-filter by bounding box
      AND p.latitude BETWEEN viewer_lat - 0.5 AND viewer_lat + 0.5
      AND p.longitude BETWEEN viewer_lon - 0.5 AND viewer_lon + 0.5
    LIMIT 50
  )
  SELECT 
    ac.id as campaign_id,
    ac.user_id,
    ac.content_id,
    -- Simple distance calculation
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
  ORDER BY random()
  LIMIT 3;
$$;

-- Create optimized indexes
DROP INDEX IF EXISTS idx_ad_campaigns_active;
DROP INDEX IF EXISTS idx_profiles_location;

CREATE INDEX idx_ad_campaigns_active 
ON ad_campaigns(status, start_time, end_time)
WHERE status = 'active';

CREATE INDEX idx_profiles_location 
ON profiles(latitude, longitude)
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;