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