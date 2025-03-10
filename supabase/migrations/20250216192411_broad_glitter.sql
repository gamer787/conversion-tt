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
  SELECT 
    ac.id as campaign_id,
    ac.user_id,
    ac.content_id,
    -- Basic Euclidean distance (approximate but fast)
    111.045 * sqrt(
      power(p.latitude - viewer_lat, 2) + 
      power(p.longitude - viewer_lon, 2)
    ) as distance
  FROM ad_campaigns ac
  JOIN profiles p ON p.id = ac.user_id
  WHERE 
    ac.status = 'active'
    AND ac.start_time <= now()
    AND ac.end_time > now()
    AND p.latitude IS NOT NULL
    AND p.longitude IS NOT NULL
    -- Simple bounding box
    AND abs(p.latitude - viewer_lat) < 5
    AND abs(p.longitude - viewer_lon) < 5
  LIMIT 3;
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