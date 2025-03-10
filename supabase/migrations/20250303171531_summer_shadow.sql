-- Drop existing function first
DROP FUNCTION IF EXISTS get_visible_ads;

-- Create function to handle ad campaign expiration
CREATE OR REPLACE FUNCTION handle_expired_campaigns()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Update expired campaigns to completed status
  UPDATE ad_campaigns
  SET status = 'completed'
  WHERE status = 'active'
  AND end_time <= now();
END;
$$;

-- Create trigger function to check expiration on update
CREATE OR REPLACE FUNCTION check_campaign_expiration()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if campaign has expired
  IF NEW.end_time <= now() AND NEW.status = 'active' THEN
    NEW.status = 'completed';
  END IF;
  RETURN NEW;
END;
$$;

-- Create trigger to check expiration on update
CREATE TRIGGER check_campaign_expiration_trigger
  BEFORE UPDATE ON ad_campaigns
  FOR EACH ROW
  EXECUTE FUNCTION check_campaign_expiration();

-- Create function to get visible ads with expiration check
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
      ELSE 50.0
    END as distance
  FROM ad_campaigns ac
  JOIN profiles p ON p.id = ac.user_id
  WHERE 
    ac.status = 'active'
    AND ac.start_time <= now()
    AND ac.end_time > now() -- Only show active, non-expired campaigns
    AND p.latitude IS NOT NULL 
    AND p.longitude IS NOT NULL
    AND abs(p.latitude - viewer_lat) <= 0.5
    AND abs(p.longitude - viewer_lon) <= 0.5
  LIMIT 3;
$$;

-- Create index for campaign expiration checks
CREATE INDEX IF NOT EXISTS idx_ad_campaigns_expiration 
ON ad_campaigns(status, end_time)
WHERE status = 'active';

-- Create function to clean up expired campaigns
CREATE OR REPLACE FUNCTION cleanup_expired_campaigns()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Move expired campaigns to completed status
  UPDATE ad_campaigns
  SET 
    status = 'completed',
    updated_at = now()
  WHERE status = 'active'
    AND end_time <= now();
END;
$$;