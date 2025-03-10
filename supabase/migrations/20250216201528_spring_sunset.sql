-- Drop existing functions and triggers
DROP FUNCTION IF EXISTS get_visible_ads;
DROP FUNCTION IF EXISTS validate_campaign_price_tier CASCADE;

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
    -- Fixed distance tiers
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
    AND abs(p.latitude - viewer_lat) <= 4.5
    AND abs(p.longitude - viewer_lon) <= 4.5
  LIMIT 3;
$$;

-- Create materialized view for price tiers
CREATE MATERIALIZED VIEW IF NOT EXISTS active_price_tiers AS
SELECT id, duration_hours, radius_km, price
FROM ad_price_tiers;

CREATE UNIQUE INDEX IF NOT EXISTS idx_active_price_tiers_unique 
ON active_price_tiers(id);

-- Create function to refresh price tiers
CREATE OR REPLACE FUNCTION refresh_price_tiers()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW active_price_tiers;
  RETURN NULL;
END;
$$;

-- Create trigger to refresh price tiers
CREATE TRIGGER refresh_price_tiers_trigger
AFTER INSERT OR UPDATE OR DELETE ON ad_price_tiers
FOR EACH STATEMENT
EXECUTE FUNCTION refresh_price_tiers();

-- Create lightweight validation function
CREATE OR REPLACE FUNCTION validate_campaign_price_tier()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.price_tier_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM active_price_tiers
      WHERE id = NEW.price_tier_id
      AND duration_hours = NEW.duration_hours
      AND radius_km = NEW.radius_km
      AND price = NEW.price
      LIMIT 1
    ) THEN
      RAISE EXCEPTION 'Invalid price tier settings';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- Create trigger for price tier validation
CREATE TRIGGER validate_campaign_price_tier_trigger
BEFORE INSERT OR UPDATE ON ad_campaigns
FOR EACH ROW
EXECUTE FUNCTION validate_campaign_price_tier();

-- Refresh price tiers view
REFRESH MATERIALIZED VIEW active_price_tiers;