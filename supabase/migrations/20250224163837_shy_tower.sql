-- Create function to get posts with badges
CREATE OR REPLACE FUNCTION get_posts_with_badges(user_ids uuid[])
RETURNS TABLE (
  id uuid,
  user_id uuid,
  type text,
  content_url text,
  caption text,
  created_at timestamptz,
  user_info jsonb
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH user_badges AS (
    SELECT DISTINCT ON (bs.user_id)
      bs.user_id,
      jsonb_build_object('role', bs.role) as badge
    FROM badge_subscriptions bs
    WHERE bs.user_id = ANY(user_ids)
      AND now() BETWEEN bs.start_date AND bs.end_date
      AND bs.cancelled_at IS NULL
    ORDER BY bs.user_id, bs.end_date DESC
  )
  SELECT 
    p.id,
    p.user_id,
    p.type::text,
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
  WHERE p.user_id = ANY(user_ids)
  ORDER BY p.created_at DESC;
$$;

-- Create function to get posts for a specific profile
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
    SELECT DISTINCT ON (bs.user_id)
      bs.user_id,
      jsonb_build_object('role', bs.role) as badge
    FROM badge_subscriptions bs
    WHERE bs.user_id = profile_id
      AND now() BETWEEN bs.start_date AND bs.end_date
      AND bs.cancelled_at IS NULL
    ORDER BY bs.user_id, bs.end_date DESC
  )
  SELECT 
    p.id,
    p.user_id,
    p.type::text,
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
    AND (post_type IS NULL OR p.type::text = post_type)
  ORDER BY p.created_at DESC;
END;
$$;