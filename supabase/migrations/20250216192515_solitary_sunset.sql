-- Drop existing function
DROP FUNCTION IF EXISTS get_visible_ads;

-- Create ultra-simplified function with no recursion or complex calculations
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
    -- Ultra-simplified distance calculation
    (abs(p.latitude - viewer_lat) + abs(p.longitude - viewer_lon)) * 111.045 as distance
  FROM (
    -- Limit the initial set of campaigns
    SELECT id, user_id, content_id, status, start_time, end_time
    FROM ad_campaigns
    WHERE status = 'active'
      AND start_time <= now()
      AND end_time > now()
    LIMIT 100
  ) ac
  JOIN (
    -- Limit the initial set of profiles
    SELECT id, latitude, longitude
    FROM profiles
    WHERE latitude IS NOT NULL 
      AND longitude IS NOT NULL
      AND abs(latitude - viewer_lat) < 5
      AND abs(longitude - viewer_lon) < 5
    LIMIT 100
  ) p ON p.id = ac.user_id
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