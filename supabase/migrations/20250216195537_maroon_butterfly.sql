/*
  # Optimize Ad Campaign Function

  1. Changes
    - Simplify get_visible_ads function to use fixed distance tiers
    - Remove complex calculations
    - Improve performance with simpler queries
    - Add proper indexes

  2. Security
    - Maintain SECURITY DEFINER
    - Keep proper search path
*/

-- Drop existing function
DROP FUNCTION IF EXISTS get_visible_ads;

-- Create ultra-simplified function with fixed distance tiers
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
  -- Get active campaigns with fixed distance tiers
  SELECT 
    ac.id as campaign_id,
    ac.user_id,
    ac.content_id,
    -- Use fixed distance tiers instead of calculations
    CASE 
      WHEN abs(p.latitude - viewer_lat) <= 0.045 THEN 5.0
      WHEN abs(p.latitude - viewer_lat) <= 0.225 THEN 25.0
      WHEN abs(p.latitude - viewer_lat) <= 0.450 THEN 50.0
      WHEN abs(p.latitude - viewer_lat) <= 0.900 THEN 100.0
      ELSE 500.0
    END as distance
  FROM ad_campaigns ac
  JOIN profiles p ON p.id = ac.user_id
  WHERE 
    ac.status = 'active'
    AND ac.start_time <= now()
    AND ac.end_time > now()
    AND p.latitude IS NOT NULL 
    AND p.longitude IS NOT NULL
    -- Simple bounding box filter
    AND abs(p.latitude - viewer_lat) <= 4.5
    AND abs(p.longitude - viewer_lon) <= 4.5
  ORDER BY random()
  LIMIT 3;
$$;

-- Create optimized indexes
DROP INDEX IF EXISTS idx_ad_campaigns_active_time;
DROP INDEX IF EXISTS idx_profiles_location;

CREATE INDEX idx_ad_campaigns_active_time 
ON ad_campaigns(status, start_time, end_time)
WHERE status = 'active';

CREATE INDEX idx_profiles_location 
ON profiles(latitude, longitude)
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;