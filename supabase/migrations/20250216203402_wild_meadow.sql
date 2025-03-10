-- Drop existing functions and triggers
DROP FUNCTION IF EXISTS get_visible_ads;
DROP FUNCTION IF EXISTS validate_campaign_price_tier CASCADE;

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
    -- Fixed distance tiers without any computation
    CASE 
      WHEN abs(p.latitude - viewer_lat) <= 0.045 THEN 5.0
      ELSE 25.0
    END as distance
  FROM ad_campaigns ac
  JOIN profiles p ON p.id = ac.user_id
  WHERE 
    ac.status = 'active'
    AND p.latitude IS NOT NULL 
    AND p.longitude IS NOT NULL
    -- Simple bounding box filter
    AND abs(p.latitude - viewer_lat) <= 0.5
    AND abs(p.longitude - viewer_lon) <= 0.5
  LIMIT 3;
$$;

-- Create simple indexes without time-based predicates
CREATE INDEX IF NOT EXISTS idx_campaigns_simple ON ad_campaigns(status);
CREATE INDEX IF NOT EXISTS idx_profiles_simple ON profiles(id, latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_price_tiers_simple ON ad_price_tiers(id);