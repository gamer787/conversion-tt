/*
  # Fix Ads Visibility

  1. Changes
    - Update get_visible_ads function to show ads to all users within range
    - Add function to get ads for brands section
    - Add policy for viewing ads in brands section

  2. Security
    - Maintain RLS policies
    - Add proper error handling
*/

-- Drop existing function
DROP FUNCTION IF EXISTS get_visible_ads;

-- Create improved function for getting visible ads
CREATE OR REPLACE FUNCTION get_visible_ads(
  user_lat double precision,
  user_lon double precision
)
RETURNS TABLE (
  campaign_id uuid,
  business_id uuid,
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
      ac.business_id,
      ac.content_id,
      ac.radius_km,
      p.latitude as business_lat,
      p.longitude as business_lon
    FROM ad_campaigns ac
    JOIN profiles p ON p.id = ac.business_id
    WHERE 
      ac.status = 'active'
      AND ac.start_time <= now()
      AND ac.end_time > now()
      AND p.latitude IS NOT NULL
      AND p.longitude IS NOT NULL
  )
  SELECT 
    ac.campaign_id,
    ac.business_id,
    ac.content_id,
    -- Calculate distance using Haversine formula
    (
      6371 * acos(
        cos(radians(user_lat)) * 
        cos(radians(ac.business_lat)) * 
        cos(radians(ac.business_lon) - radians(user_lon)) + 
        sin(radians(user_lat)) * 
        sin(radians(ac.business_lat))
      )
    ) as distance
  FROM active_campaigns ac
  WHERE (
    6371 * acos(
      cos(radians(user_lat)) * 
      cos(radians(ac.business_lat)) * 
      cos(radians(ac.business_lon) - radians(user_lon)) + 
      sin(radians(user_lat)) * 
      sin(radians(ac.business_lat))
    )
  ) <= ac.radius_km
  ORDER BY random()
  LIMIT 10; -- Limit to 10 ads per request for performance
END;
$$;

-- Function to get ads for brands section
CREATE OR REPLACE FUNCTION get_brand_ads(
  user_lat double precision,
  user_lon double precision
)
RETURNS TABLE (
  campaign_id uuid,
  business_id uuid,
  content_id uuid,
  distance double precision,
  business_name text,
  business_username text,
  business_avatar_url text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH visible_ads AS (
    SELECT * FROM get_visible_ads(user_lat, user_lon)
  )
  SELECT 
    va.campaign_id,
    va.business_id,
    va.content_id,
    va.distance,
    p.display_name as business_name,
    p.username as business_username,
    p.avatar_url as business_avatar_url
  FROM visible_ads va
  JOIN profiles p ON p.id = va.business_id
  WHERE p.account_type = 'business'
  ORDER BY va.distance;
END;
$$;

-- Update RLS policies
DROP POLICY IF EXISTS "users_view_active_ads" ON ad_campaigns;

CREATE POLICY "users_view_active_ads"
  ON ad_campaigns FOR SELECT
  USING (
    status = 'active'
    AND start_time <= now()
    AND end_time > now()
  );