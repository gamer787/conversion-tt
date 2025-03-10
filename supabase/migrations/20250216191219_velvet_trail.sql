-- Drop existing function
DROP FUNCTION IF EXISTS get_visible_ads;

-- Create optimized function with CTEs and simplified distance calculation
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
      -- Rough bounding box filter
      AND p.latitude BETWEEN viewer_lat - 5 AND viewer_lat + 5
      AND p.longitude BETWEEN viewer_lon - 5 AND viewer_lon + 5
  ),
  campaigns_with_distance AS (
    SELECT 
      ac.id as campaign_id,
      ac.user_id,
      ac.content_id,
      -- Simplified distance calculation (in km)
      (
        6371 * 2 * asin(
          sqrt(
            power(sin((radians(ac.latitude) - radians(viewer_lat)) / 2), 2) +
            cos(radians(viewer_lat)) * cos(radians(ac.latitude)) *
            power(sin((radians(ac.longitude) - radians(viewer_lon)) / 2), 2)
          )
        )
      ) as distance
    FROM active_campaigns ac
  )
  SELECT 
    campaign_id,
    user_id,
    content_id,
    distance
  FROM campaigns_with_distance
  WHERE distance <= 500 -- Maximum radius limit
  ORDER BY random()
  LIMIT 10;
$$;