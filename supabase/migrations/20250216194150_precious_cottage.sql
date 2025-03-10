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
  SELECT 
    ac.id as campaign_id,
    ac.user_id,
    ac.content_id,
    -- Use simple rectangular distance (much faster than spherical)
    ROUND(
      CAST(
        111.111 * 
        GREATEST(
          ABS(p.latitude - viewer_lat),
          ABS(p.longitude - viewer_lon) * COS(RADIANS(viewer_lat))
        ) AS numeric
      ),
      3
    ) as distance
  FROM ad_campaigns ac
  JOIN profiles p ON p.id = ac.user_id
  WHERE 
    ac.status = 'active'
    AND ac.start_time <= now()
    AND ac.end_time > now()
    AND p.latitude IS NOT NULL 
    AND p.longitude IS NOT NULL
    -- Use simple bounding box for initial filtering
    AND p.latitude BETWEEN viewer_lat - 0.5 AND viewer_lat + 0.5
    AND p.longitude BETWEEN viewer_lon - 0.5 AND viewer_lon + 0.5
  -- Limit results to prevent excessive computation
  ORDER BY RANDOM()
  LIMIT 3;
$$;