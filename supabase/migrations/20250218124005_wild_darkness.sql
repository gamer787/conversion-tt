-- Drop existing function
DROP FUNCTION IF EXISTS get_active_badge;

-- Create enhanced function with profile information
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
  WHERE bs.user_id = auth.uid()
    AND CURRENT_TIMESTAMP BETWEEN bs.start_date AND bs.end_date
    AND bs.cancelled_at IS NULL
  ORDER BY bs.end_date DESC
  LIMIT 1;
$$;