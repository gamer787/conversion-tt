/*
  # Simplify ad campaign visibility function

  1. Changes
    - Replace complex distance calculations with simple bounding box checks
    - Use fixed distance tiers instead of precise calculations
    - Limit result set size
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
  -- Get active campaigns with minimal computation
  SELECT 
    ac.id as campaign_id,
    ac.user_id,
    ac.content_id,
    -- Use fixed distance tiers instead of calculations
    CASE 
      WHEN abs(p.latitude - viewer_lat) <= 0.045 THEN 5.0  -- ~5km
      WHEN abs(p.latitude - viewer_lat) <= 0.225 THEN 25.0 -- ~25km
      WHEN abs(p.latitude - viewer_lat) <= 0.450 THEN 50.0 -- ~50km
      WHEN abs(p.latitude - viewer_lat) <= 0.900 THEN 100.0 -- ~100km
      ELSE 500.0 -- Everything else
    END as distance
  FROM (
    -- Limit initial set of campaigns
    SELECT id, user_id, content_id
    FROM ad_campaigns
    WHERE status = 'active'
      AND start_time <= now()
      AND end_time > now()
    LIMIT 50
  ) ac
  JOIN (
    -- Limit initial set of profiles
    SELECT id, latitude, longitude
    FROM profiles
    WHERE latitude IS NOT NULL 
      AND longitude IS NOT NULL
      AND latitude BETWEEN viewer_lat - 4.5 AND viewer_lat + 4.5
      AND longitude BETWEEN viewer_lon - 4.5 AND viewer_lon + 4.5
    LIMIT 50
  ) p ON p.id = ac.user_id
  ORDER BY random()
  LIMIT 3;
$$;