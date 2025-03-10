-- Drop existing function
DROP FUNCTION IF EXISTS get_profile_links;

-- Create function to get profile links with badges
CREATE OR REPLACE FUNCTION get_profile_links(
  profile_id uuid,
  include_badges boolean DEFAULT true
)
RETURNS TABLE (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  account_type text,
  badge jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Get profile type
  DECLARE
    is_business boolean;
  BEGIN
    SELECT (p.account_type = 'business') INTO is_business
    FROM profiles p
    WHERE p.id = profile_id;

    IF is_business THEN
      -- For business accounts, get followers
      RETURN QUERY
      WITH user_badges AS (
        SELECT DISTINCT ON (bs.user_id)
          bs.user_id,
          jsonb_build_object('role', bs.role) as badge
        FROM badge_subscriptions bs
        WHERE now() BETWEEN bs.start_date AND bs.end_date
          AND bs.cancelled_at IS NULL
        ORDER BY bs.user_id, bs.end_date DESC
      )
      SELECT 
        p.id,
        p.username,
        p.display_name,
        p.avatar_url,
        p.account_type::text,
        CASE WHEN include_badges THEN ub.badge ELSE NULL END
      FROM follows f
      JOIN profiles p ON p.id = f.follower_id
      LEFT JOIN user_badges ub ON ub.user_id = p.id
      WHERE f.following_id = profile_id;
    ELSE
      -- For personal accounts, get mutual friends
      RETURN QUERY
      WITH connected_users AS (
        SELECT
          CASE
            WHEN fr.sender_id = profile_id THEN fr.receiver_id
            ELSE fr.sender_id
          END as user_id
        FROM friend_requests fr
        WHERE fr.status = 'accepted'
          AND (fr.sender_id = profile_id OR fr.receiver_id = profile_id)
      ),
      user_badges AS (
        SELECT DISTINCT ON (bs.user_id)
          bs.user_id,
          jsonb_build_object('role', bs.role) as badge
        FROM badge_subscriptions bs
        WHERE now() BETWEEN bs.start_date AND bs.end_date
          AND bs.cancelled_at IS NULL
        ORDER BY bs.user_id, bs.end_date DESC
      )
      SELECT 
        p.id,
        p.username,
        p.display_name,
        p.avatar_url,
        p.account_type::text,
        CASE WHEN include_badges THEN ub.badge ELSE NULL END
      FROM connected_users cu
      JOIN profiles p ON p.id = cu.user_id
      LEFT JOIN user_badges ub ON ub.user_id = p.id;
    END IF;
  END;
END;
$$;