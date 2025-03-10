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
  -- Get active campaigns with minimal computation
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
    AND ac.start_time <= now()
    AND ac.end_time > now()
    AND p.latitude IS NOT NULL 
    AND p.longitude IS NOT NULL
    -- Simple bounding box filter
    AND abs(p.latitude - viewer_lat) <= 0.5
    AND abs(p.longitude - viewer_lon) <= 0.5
  LIMIT 3;
$$;

-- Drop existing indexes
DROP INDEX IF EXISTS idx_ad_campaigns_active_time;
DROP INDEX IF EXISTS idx_profiles_location;
DROP INDEX IF EXISTS idx_ad_campaigns_price_tier;
DROP INDEX IF EXISTS idx_ad_campaigns_status;
DROP INDEX IF EXISTS idx_ad_campaigns_times;

-- Create simple indexes without complex predicates
CREATE INDEX idx_ad_campaigns_status ON ad_campaigns(status);
CREATE INDEX idx_ad_campaigns_times ON ad_campaigns(start_time, end_time);
CREATE INDEX idx_profiles_location ON profiles(latitude, longitude);
CREATE INDEX idx_ad_campaigns_price_tier ON ad_campaigns(price_tier_id);