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
  -- First get a small set of active campaigns within a rough bounding box
  WITH active_ads AS (
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
      -- Simple bounding box filter
      AND p.latitude BETWEEN viewer_lat - 1 AND viewer_lat + 1
      AND p.longitude BETWEEN viewer_lon - 1 AND viewer_lon + 1
    LIMIT 20  -- Limit initial result set
  )
  SELECT 
    aa.id as campaign_id,
    aa.user_id,
    aa.content_id,
    -- Simple distance approximation (faster than great circle)
    ROUND(
      CAST(
        111.111 * 
        SQRT(
          POWER(aa.latitude - viewer_lat, 2) + 
          POWER((aa.longitude - viewer_lon) * COS(RADIANS(viewer_lat)), 2)
        ) AS numeric
      ),
      3
    ) as distance
  FROM active_ads aa
  ORDER BY RANDOM()
  LIMIT 5;
$$;