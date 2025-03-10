/*
  # Simplify ad campaign creation

  1. Changes
    - Remove complex triggers and validations
    - Add simple check constraints
    - Ensure proper indexing
*/

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS validate_ad_campaign_trigger ON ad_campaigns;
DROP TRIGGER IF EXISTS validate_price_tier_trigger ON ad_campaigns;
DROP FUNCTION IF EXISTS validate_ad_campaign();
DROP FUNCTION IF EXISTS validate_price_tier();

-- Add check constraints to ad_campaigns
ALTER TABLE ad_campaigns
ADD CONSTRAINT valid_campaign_duration CHECK (duration_hours > 0),
ADD CONSTRAINT valid_campaign_radius CHECK (radius_km > 0),
ADD CONSTRAINT valid_campaign_price CHECK (price > 0),
ADD CONSTRAINT valid_campaign_times CHECK (start_time < end_time);

-- Create index for price tier lookups
CREATE INDEX IF NOT EXISTS idx_ad_campaigns_price_tier 
ON ad_campaigns(price_tier_id)
WHERE price_tier_id IS NOT NULL;

-- Create index for active campaigns
CREATE INDEX IF NOT EXISTS idx_ad_campaigns_active 
ON ad_campaigns(status, start_time, end_time)
WHERE status = 'active';

-- Drop and recreate simplified policies
DROP POLICY IF EXISTS "users_manage_own_ads" ON ad_campaigns;
DROP POLICY IF EXISTS "users_view_active_ads" ON ad_campaigns;

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