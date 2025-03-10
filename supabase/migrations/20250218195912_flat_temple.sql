-- Drop existing function
DROP FUNCTION IF EXISTS get_active_badge;

-- Create enhanced function with proper parameter handling
CREATE OR REPLACE FUNCTION get_active_badge(user_id uuid)
RETURNS TABLE (
  category text,
  role text,
  days_remaining integer,
  subscription_id uuid,
  display_name text,
  username text,
  avatar_url text
) 
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    bs.category,
    bs.role,
    EXTRACT(DAY FROM (bs.end_date - CURRENT_TIMESTAMP))::integer as days_remaining,
    bs.id as subscription_id,
    p.display_name,
    p.username,
    p.avatar_url
  FROM badge_subscriptions bs
  JOIN profiles p ON p.id = bs.user_id
  WHERE bs.user_id = user_id
    AND CURRENT_TIMESTAMP BETWEEN bs.start_date AND bs.end_date
    AND bs.cancelled_at IS NULL
  ORDER BY bs.end_date DESC
  LIMIT 1;
$$;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_badge_subscriptions_active 
ON badge_subscriptions(user_id, start_date, end_date, cancelled_at)
WHERE cancelled_at IS NULL;