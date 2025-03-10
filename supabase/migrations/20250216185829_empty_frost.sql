/*
  # Fix ambiguous column reference in get_visible_ads function

  1. Changes
    - Rename function parameters to avoid ambiguity
    - Update Haversine formula calculation
    - Improve readability with better variable names

  2. Security
    - Maintain existing security policies
    - Keep SECURITY DEFINER setting
*/

-- Drop existing function
DROP FUNCTION IF EXISTS get_visible_ads;

-- Create improved function with renamed parameters
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
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH active_campaigns AS (
    -- Get all active campaigns
    SELECT 
      ac.id as campaign_id,
      ac.user_id,
      ac.content_id,
      ac.radius_km,
      p.latitude as advertiser_lat,
      p.longitude as advertiser_lon
    FROM ad_campaigns ac
    JOIN profiles p ON p.id = ac.user_id
    WHERE 
      ac.status = 'active'
      AND ac.start_time <= now()
      AND ac.end_time > now()
      AND p.latitude IS NOT NULL
      AND p.longitude IS NOT NULL
  )
  SELECT 
    ac.campaign_id,
    ac.user_id,
    ac.content_id,
    -- Calculate distance using Haversine formula
    (
      6371 * acos(
        cos(radians(viewer_lat)) * 
        cos(radians(ac.advertiser_lat)) * 
        cos(radians(ac.advertiser_lon) - radians(viewer_lon)) + 
        sin(radians(viewer_lat)) * 
        sin(radians(ac.advertiser_lat))
      )
    ) as distance
  FROM active_campaigns ac
  WHERE (
    6371 * acos(
      cos(radians(viewer_lat)) * 
      cos(radians(ac.advertiser_lat)) * 
      cos(radians(ac.advertiser_lon) - radians(viewer_lon)) + 
      sin(radians(viewer_lat)) * 
      sin(radians(ac.advertiser_lat))
    )
  ) <= ac.radius_km
  ORDER BY random()
  LIMIT 10; -- Limit to 10 ads per request for performance
END;
$$;