-- Drop existing functions and triggers
DROP FUNCTION IF EXISTS get_visible_ads;
DROP FUNCTION IF EXISTS validate_price_tier;
DROP TRIGGER IF EXISTS validate_price_tier_trigger ON ad_campaigns;

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
  SELECT 
    ac.id as campaign_id,
    ac.user_id,
    ac.content_id,
    -- Simple distance calculation
    CASE 
      WHEN abs(p.latitude - viewer_lat) <= 0.045 THEN 5.0
      WHEN abs(p.latitude - viewer_lat) <= 0.225 THEN 25.0
      WHEN abs(p.latitude - viewer_lat) <= 0.450 THEN 50.0
      WHEN abs(p.latitude - viewer_lat) <= 0.900 THEN 100.0
      ELSE 500.0
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
    AND abs(p.latitude - viewer_lat) <= 4.5
    AND abs(p.longitude - viewer_lon) <= 4.5
  LIMIT 3;
$$;

-- Add basic check constraints
ALTER TABLE ad_campaigns
DROP CONSTRAINT IF EXISTS valid_campaign_duration,
DROP CONSTRAINT IF EXISTS valid_campaign_radius,
DROP CONSTRAINT IF EXISTS valid_campaign_price,
DROP CONSTRAINT IF EXISTS valid_campaign_times,
ADD CONSTRAINT valid_campaign_duration CHECK (duration_hours > 0),
ADD CONSTRAINT valid_campaign_radius CHECK (radius_km > 0),
ADD CONSTRAINT valid_campaign_price CHECK (price > 0),
ADD CONSTRAINT valid_campaign_times CHECK (start_time < end_time);

-- Create function to validate price tier
CREATE OR REPLACE FUNCTION validate_campaign_price_tier()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Skip validation if price_tier_id is NULL
  IF NEW.price_tier_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Validate price tier matches campaign settings
  IF NOT EXISTS (
    SELECT 1 FROM ad_price_tiers
    WHERE id = NEW.price_tier_id
    AND duration_hours = NEW.duration_hours
    AND radius_km = NEW.radius_km
    AND price = NEW.price
  ) THEN
    RAISE EXCEPTION 'Invalid price tier or campaign settings';
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger for price tier validation
CREATE TRIGGER validate_campaign_price_tier_trigger
  BEFORE INSERT OR UPDATE ON ad_campaigns
  FOR EACH ROW
  EXECUTE FUNCTION validate_campaign_price_tier();

-- Create optimized indexes
DROP INDEX IF EXISTS idx_ad_campaigns_active_time;
DROP INDEX IF EXISTS idx_profiles_location;

CREATE INDEX idx_ad_campaigns_active_time 
ON ad_campaigns(status, start_time, end_time)
WHERE status = 'active';

CREATE INDEX idx_profiles_location 
ON profiles(latitude, longitude)
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;