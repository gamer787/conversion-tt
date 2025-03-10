/*
  # Update ad campaign policies

  1. Changes
    - Add RLS policies for price tiers
    - Update ad campaigns policies
    - Add validation triggers

  2. Security
    - Enable RLS
    - Add policies for viewing and using price tiers
*/

-- Drop existing policies
DROP POLICY IF EXISTS "users_manage_own_ads" ON ad_campaigns;
DROP POLICY IF EXISTS "users_view_active_ads" ON ad_campaigns;
DROP POLICY IF EXISTS "price_tiers_viewable_by_everyone" ON ad_price_tiers;

-- Create new policies for price tiers
CREATE POLICY "price_tiers_viewable_by_everyone"
  ON ad_price_tiers FOR SELECT
  USING (true);

-- Create policies for ad campaigns
CREATE POLICY "users_manage_own_ads"
  ON ad_campaigns
  USING (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM ad_price_tiers
      WHERE id = price_tier_id
    )
  );

CREATE POLICY "users_view_active_ads"
  ON ad_campaigns FOR SELECT
  USING (
    status = 'active'
    AND start_time <= now()
    AND end_time > now()
  );

-- Create trigger to validate price tier when creating campaign
CREATE OR REPLACE FUNCTION validate_ad_campaign()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Verify price tier exists and matches campaign settings
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

-- Create trigger
DROP TRIGGER IF EXISTS validate_ad_campaign_trigger ON ad_campaigns;
CREATE TRIGGER validate_ad_campaign_trigger
  BEFORE INSERT OR UPDATE ON ad_campaigns
  FOR EACH ROW
  EXECUTE FUNCTION validate_ad_campaign();