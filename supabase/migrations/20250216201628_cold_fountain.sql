-- Drop existing functions and triggers
DROP FUNCTION IF EXISTS get_visible_ads;
DROP FUNCTION IF EXISTS validate_campaign_price_tier CASCADE;
DROP MATERIALIZED VIEW IF EXISTS active_price_tiers;

-- Create simplified function without recursion
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
    -- Fixed distance tiers without computation
    CASE 
      WHEN abs(p.latitude - viewer_lat) <= 0.045 THEN 5.0
      WHEN abs(p.latitude - viewer_lat) <= 0.225 THEN 25.0
      WHEN abs(p.latitude - viewer_lat) <= 0.450 THEN 50.0
      ELSE 100.0
    END as distance
  FROM ad_campaigns ac
  JOIN profiles p ON p.id = ac.user_id
  WHERE 
    ac.status = 'active'
    AND ac.start_time <= now()
    AND ac.end_time > now()
    AND p.latitude IS NOT NULL 
    AND p.longitude IS NOT NULL
    AND abs(p.latitude - viewer_lat) <= 4.5
    AND abs(p.longitude - viewer_lon) <= 4.5
  LIMIT 3;
$$;

-- Add basic constraints
ALTER TABLE ad_campaigns
DROP CONSTRAINT IF EXISTS valid_campaign_duration,
DROP CONSTRAINT IF EXISTS valid_campaign_radius,
DROP CONSTRAINT IF EXISTS valid_campaign_price,
DROP CONSTRAINT IF EXISTS valid_campaign_times,
ADD CONSTRAINT valid_campaign_duration CHECK (duration_hours > 0),
ADD CONSTRAINT valid_campaign_radius CHECK (radius_km > 0),
ADD CONSTRAINT valid_campaign_price CHECK (price > 0),
ADD CONSTRAINT valid_campaign_times CHECK (start_time < end_time);

-- Create optimized indexes
DROP INDEX IF EXISTS idx_ad_campaigns_active_time;
DROP INDEX IF EXISTS idx_profiles_location;
DROP INDEX IF EXISTS idx_ad_campaigns_price_tier;

CREATE INDEX idx_ad_campaigns_active_time 
ON ad_campaigns(status, start_time, end_time)
WHERE status = 'active';

CREATE INDEX idx_profiles_location 
ON profiles(latitude, longitude)
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

CREATE INDEX idx_ad_campaigns_price_tier
ON ad_campaigns(price_tier_id, duration_hours, radius_km, price);