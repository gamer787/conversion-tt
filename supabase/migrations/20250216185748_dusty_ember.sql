/*
  # Update ad system to allow all users to run ads

  1. Changes
    - Rename business_id to user_id in ad_campaigns table
    - Update RLS policies to allow all users to create ads
    - Update functions to work with all user types
    - Add new indexes for better performance

  2. Security
    - Maintain RLS policies for ad management
    - Ensure users can only manage their own ads
*/

-- Rename business_id to user_id in ad_campaigns table
ALTER TABLE ad_campaigns
RENAME COLUMN business_id TO user_id;

-- Drop existing policies
DROP POLICY IF EXISTS "businesses_manage_own_ads" ON ad_campaigns;
DROP POLICY IF EXISTS "users_view_active_ads" ON ad_campaigns;

-- Create new policies for all users
CREATE POLICY "users_manage_own_ads"
  ON ad_campaigns
  USING (user_id = auth.uid());

CREATE POLICY "users_view_active_ads"
  ON ad_campaigns FOR SELECT
  USING (
    status = 'active'
    AND start_time <= now()
    AND end_time > now()
  );

-- Drop existing functions
DROP FUNCTION IF EXISTS get_visible_ads;
DROP FUNCTION IF EXISTS get_brand_ads;

-- Create improved function for getting visible ads
CREATE OR REPLACE FUNCTION get_visible_ads(
  user_lat double precision,
  user_lon double precision
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
      p.latitude as user_lat,
      p.longitude as user_lon
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
        cos(radians(user_lat)) * 
        cos(radians(ac.user_lat)) * 
        cos(radians(ac.user_lon) - radians(user_lon)) + 
        sin(radians(user_lat)) * 
        sin(radians(ac.user_lat))
      )
    ) as distance
  FROM active_campaigns ac
  WHERE (
    6371 * acos(
      cos(radians(user_lat)) * 
      cos(radians(ac.user_lat)) * 
      cos(radians(ac.user_lon) - radians(user_lon)) + 
      sin(radians(user_lat)) * 
      sin(radians(ac.user_lat))
    )
  ) <= ac.radius_km
  ORDER BY random()
  LIMIT 10; -- Limit to 10 ads per request for performance
END;
$$;

-- Update indexes
DROP INDEX IF EXISTS idx_ad_campaigns_business;
CREATE INDEX idx_ad_campaigns_user ON ad_campaigns(user_id);
CREATE INDEX idx_ad_campaigns_active_location ON ad_campaigns(user_id, status)
WHERE status = 'active';