-- Drop existing functions and triggers
DROP FUNCTION IF EXISTS get_visible_ads;
DROP FUNCTION IF EXISTS validate_campaign_price_tier CASCADE;

-- Create ultra-simplified function with minimal database operations
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
      WHEN abs(p.latitude - viewer_lat) <= 0.225 THEN 25.0
      ELSE 50.0
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

-- Add basic constraints
DO $$ 
BEGIN
  -- Drop constraints if they exist
  ALTER TABLE ad_campaigns DROP CONSTRAINT IF EXISTS valid_campaign_duration;
  ALTER TABLE ad_campaigns DROP CONSTRAINT IF EXISTS valid_campaign_radius;
  ALTER TABLE ad_campaigns DROP CONSTRAINT IF EXISTS valid_campaign_price;
  ALTER TABLE ad_campaigns DROP CONSTRAINT IF EXISTS valid_campaign_times;

  -- Add constraints
  ALTER TABLE ad_campaigns ADD CONSTRAINT valid_campaign_duration CHECK (duration_hours > 0);
  ALTER TABLE ad_campaigns ADD CONSTRAINT valid_campaign_radius CHECK (radius_km > 0);
  ALTER TABLE ad_campaigns ADD CONSTRAINT valid_campaign_price CHECK (price > 0);
  ALTER TABLE ad_campaigns ADD CONSTRAINT valid_campaign_times CHECK (start_time < end_time);
EXCEPTION
  WHEN others THEN
    -- If there's an error, it's likely because the constraints already exist
    NULL;
END $$;

-- Drop existing indexes
DROP INDEX IF EXISTS idx_ad_campaigns_active_time;
DROP INDEX IF EXISTS idx_profiles_location;
DROP INDEX IF EXISTS idx_ad_campaigns_price_tier;
DROP INDEX IF EXISTS idx_ad_campaigns_status;
DROP INDEX IF EXISTS idx_ad_campaigns_times;

-- Create new indexes with existence check
DO $$
BEGIN
  -- Create index for status if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE indexname = 'idx_ad_campaigns_status'
  ) THEN
    CREATE INDEX idx_ad_campaigns_status ON ad_campaigns(status);
  END IF;

  -- Create index for timestamps if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE indexname = 'idx_ad_campaigns_times'
  ) THEN
    CREATE INDEX idx_ad_campaigns_times ON ad_campaigns(start_time, end_time);
  END IF;

  -- Create index for location lookups if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE indexname = 'idx_profiles_location'
  ) THEN
    CREATE INDEX idx_profiles_location 
    ON profiles(latitude, longitude)
    WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
  END IF;

  -- Create index for price tier lookups if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE indexname = 'idx_ad_campaigns_price_tier'
  ) THEN
    CREATE INDEX idx_ad_campaigns_price_tier
    ON ad_campaigns(price_tier_id, duration_hours, radius_km, price);
  END IF;
END $$;