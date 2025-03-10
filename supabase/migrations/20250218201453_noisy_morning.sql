-- Drop existing function
DROP FUNCTION IF EXISTS get_active_badge;

-- Create enhanced function with proper parameter handling and error handling
CREATE OR REPLACE FUNCTION get_active_badge(target_user_id uuid)
RETURNS TABLE (
  category text,
  role text,
  days_remaining integer,
  subscription_id uuid,
  display_name text,
  username text,
  avatar_url text
) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Validate input
  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'target_user_id parameter is required';
  END IF;

  -- Check if user exists
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = target_user_id) THEN
    RETURN;
  END IF;

  -- Get active badge with proper ordering and uniqueness
  RETURN QUERY
  SELECT DISTINCT ON (bs.user_id)
    bs.category,
    bs.role,
    EXTRACT(DAY FROM (bs.end_date - CURRENT_TIMESTAMP))::integer as days_remaining,
    bs.id as subscription_id,
    p.display_name,
    p.username,
    p.avatar_url
  FROM badge_subscriptions bs
  JOIN profiles p ON p.id = bs.user_id
  WHERE bs.user_id = target_user_id
    AND CURRENT_TIMESTAMP BETWEEN bs.start_date AND bs.end_date
    AND bs.cancelled_at IS NULL
  ORDER BY bs.user_id, bs.end_date DESC
  LIMIT 1;
END;
$$;