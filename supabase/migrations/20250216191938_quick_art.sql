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
  WITH active_campaigns AS (
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
      AND p.latitude IS NOT NULL
      AND p.longitude IS NOT NULL
      -- Pre-filter by bounding box
      AND p.latitude BETWEEN viewer_lat - 5 AND viewer_lat + 5
      AND p.longitude BETWEEN viewer_lon - 5 AND viewer_lon + 5
  )
  SELECT 
    ac.id as campaign_id,
    ac.user_id,
    ac.content_id,
    -- Simplified distance calculation
    111.045 * DEGREES(ACOS(
      LEAST(1.0, 
        COS(RADIANS(viewer_lat)) * 
        COS(RADIANS(ac.latitude)) * 
        COS(RADIANS(ac.longitude - viewer_lon)) +
        SIN(RADIANS(viewer_lat)) * 
        SIN(RADIANS(ac.latitude))
      )
    )) as distance
  FROM active_campaigns ac
  ORDER BY RANDOM()
  LIMIT 5;
$$;

-- Add is_test column if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'ad_campaigns' AND column_name = 'is_test'
  ) THEN
    ALTER TABLE ad_campaigns ADD COLUMN is_test boolean NOT NULL DEFAULT false;
  END IF;
END $$;

-- Create or replace indexes for better performance
DROP INDEX IF EXISTS idx_ad_campaigns_active_time;
DROP INDEX IF EXISTS idx_profiles_location;

CREATE INDEX idx_ad_campaigns_active_time 
ON ad_campaigns(status, start_time, end_time)
WHERE status = 'active';

CREATE INDEX idx_profiles_location 
ON profiles(latitude, longitude)
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;