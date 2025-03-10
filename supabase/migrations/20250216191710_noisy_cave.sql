-- Add test mode support for ad campaigns
ALTER TABLE ad_campaigns 
ADD COLUMN is_test boolean NOT NULL DEFAULT false;

-- Modify existing policies to allow test campaigns
DROP POLICY IF EXISTS "users_manage_own_ads" ON ad_campaigns;
DROP POLICY IF EXISTS "users_view_active_ads" ON ad_campaigns;

-- Create new policies that handle test campaigns
CREATE POLICY "users_manage_own_ads"
  ON ad_campaigns
  USING (
    user_id = auth.uid()
    AND (
      -- Allow test campaigns for all users
      is_test = true
      -- Or require business account for real campaigns
      OR EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
        AND account_type = 'business'
      )
    )
  );

CREATE POLICY "users_view_active_ads"
  ON ad_campaigns FOR SELECT
  USING (
    status = 'active'
    AND start_time <= now()
    AND end_time > now()
    -- Only show non-test campaigns to users
    AND is_test = false
  );

-- Update get_visible_ads function to exclude test campaigns
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
    -- Simplified distance calculation using law of cosines
    (
      6371 * acos(
        least(1.0, -- Prevent domain error in acos
          cos(radians(viewer_lat)) * 
          cos(radians(p.latitude)) * 
          cos(radians(p.longitude - viewer_lon)) +
          sin(radians(viewer_lat)) * 
          sin(radians(p.latitude))
        )
      )
    ) as distance
  FROM ad_campaigns ac
  JOIN profiles p ON p.id = ac.user_id
  WHERE 
    ac.status = 'active'
    AND ac.start_time <= now()
    AND ac.end_time > now()
    AND ac.is_test = false
    AND p.latitude IS NOT NULL
    AND p.longitude IS NOT NULL
    -- Rough bounding box filter
    AND p.latitude BETWEEN viewer_lat - (ac.radius_km / 111.0) AND viewer_lat + (ac.radius_km / 111.0)
    AND p.longitude BETWEEN viewer_lon - (ac.radius_km / (111.0 * cos(radians(viewer_lat)))) 
                           AND viewer_lon + (ac.radius_km / (111.0 * cos(radians(viewer_lat))))
  ORDER BY random()
  LIMIT 10;
$$;