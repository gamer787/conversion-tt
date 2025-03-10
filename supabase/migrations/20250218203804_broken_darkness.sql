-- Create function to get posts with badges
CREATE OR REPLACE FUNCTION get_profile_posts(
  profile_id uuid,
  post_type text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  type text,
  content_url text,
  caption text,
  created_at timestamptz,
  user_info jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH user_badges AS (
    SELECT DISTINCT ON (user_id)
      user_id,
      jsonb_build_object('role', role) as badge
    FROM badge_subscriptions
    WHERE user_id = profile_id
      AND now() BETWEEN start_date AND end_date
      AND cancelled_at IS NULL
    ORDER BY user_id, end_date DESC
  )
  SELECT 
    p.id,
    p.user_id,
    p.type,
    p.content_url,
    p.caption,
    p.created_at,
    jsonb_build_object(
      'username', u.username,
      'display_name', u.display_name,
      'avatar_url', u.avatar_url,
      'badge', COALESCE(ub.badge, null)
    ) as user_info
  FROM posts p
  JOIN profiles u ON u.id = p.user_id
  LEFT JOIN user_badges ub ON ub.user_id = p.user_id
  WHERE p.user_id = profile_id
    AND (post_type IS NULL OR CAST(p.type AS text) = post_type)
  ORDER BY p.created_at DESC;
END;
$$;