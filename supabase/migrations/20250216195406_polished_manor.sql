/*
  # Fix Ad Campaign Optimizations

  1. Changes
    - Simplify get_visible_ads function
    - Add price tier validation using trigger instead of constraint
    - Update indexes for better performance

  2. Security
    - Maintain RLS policies
    - Add validation through trigger function
*/

-- Drop existing function
DROP FUNCTION IF EXISTS get_visible_ads;

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
    -- Use fixed distance tiers instead of calculations
    CASE 
      WHEN abs(p.latitude - viewer_lat) <= 0.045 AND abs(p.longitude - viewer_lon) <= 0.045 THEN 5
      WHEN abs(p.latitude - viewer_lat) <= 0.225 AND abs(p.longitude - viewer_lon) <= 0.225 THEN 25
      WHEN abs(p.latitude - viewer_lat) <= 0.450 AND abs(p.longitude - viewer_lon) <= 0.450 THEN 50
      WHEN abs(p.latitude - viewer_lat) <= 0.900 AND abs(p.longitude - viewer_lon) <= 0.900 THEN 100
      ELSE 500
    END as distance
  FROM ad_campaigns ac
  JOIN profiles p ON p.id = ac.user_id
  WHERE 
    ac.status = 'active'
    AND ac.start_time <= now()
    AND ac.end_time > now()
    AND p.latitude IS NOT NULL 
    AND p.longitude IS NOT NULL
    -- Use simple bounding box for initial filtering
    AND p.latitude BETWEEN viewer_lat - 4.5 AND viewer_lat + 4.5
    AND p.longitude BETWEEN viewer_lon - 4.5 AND viewer_lon + 4.5
  -- Limit results and randomize
  ORDER BY random()
  LIMIT 3;
$$;

-- Create index for price tier lookups
CREATE INDEX IF NOT EXISTS idx_price_tiers_settings 
ON ad_price_tiers(duration_hours, radius_km, price);

-- Create function to validate price tier
CREATE OR REPLACE FUNCTION validate_price_tier()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Verify price tier exists and matches campaign settings
  IF NEW.price_tier_id IS NULL THEN
    RAISE EXCEPTION 'Price tier is required';
  END IF;

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
DROP TRIGGER IF EXISTS validate_price_tier_trigger ON ad_campaigns;
CREATE TRIGGER validate_price_tier_trigger
  BEFORE INSERT OR UPDATE ON ad_campaigns
  FOR EACH ROW
  EXECUTE FUNCTION validate_price_tier();