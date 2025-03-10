-- Create function to get post badges
CREATE OR REPLACE FUNCTION get_post_badges(post_ids uuid[])
RETURNS TABLE (
  post_id uuid,
  badge jsonb
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH post_users AS (
    SELECT DISTINCT user_id
    FROM posts
    WHERE id = ANY(post_ids)
  ),
  user_badges AS (
    SELECT 
      user_id,
      jsonb_build_object('role', role) as badge
    FROM badge_subscriptions
    WHERE user_id IN (SELECT user_id FROM post_users)
      AND now() BETWEEN start_date AND end_date
      AND cancelled_at IS NULL
    ORDER BY end_date DESC
  )
  SELECT 
    p.id as post_id,
    ub.badge
  FROM posts p
  LEFT JOIN user_badges ub ON ub.user_id = p.user_id
  WHERE p.id = ANY(post_ids);
$$;

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
      'badge', (
        SELECT jsonb_build_object('role', role)
        FROM badge_subscriptions
        WHERE user_id = p.user_id
          AND now() BETWEEN start_date AND end_date
          AND cancelled_at IS NULL
        ORDER BY end_date DESC
        LIMIT 1
      )
    ) as user_info
  FROM posts p
  JOIN profiles u ON u.id = p.user_id
  WHERE p.user_id = ANY(user_ids)
  ORDER BY p.created_at DESC;
$$;