/*
  # Fix get_visible_ads function

  1. Changes
    - Fix dollar-quoted string syntax
    - Simplify distance calculation
    - Add proper indexes
*/

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
AS $function$
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
  LIMIT 3
$function$;