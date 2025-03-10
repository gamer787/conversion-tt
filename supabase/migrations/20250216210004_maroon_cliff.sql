-- Drop existing function
DROP FUNCTION IF EXISTS get_visible_ads(double precision, double precision);

-- Create optimized function for getting visible ads with social features
CREATE OR REPLACE FUNCTION get_visible_ads(
  viewer_lat double precision,
  viewer_lon double precision
)
RETURNS TABLE (
  campaign_id uuid,
  user_id uuid,
  content_id uuid,
  distance double precision,
  content jsonb
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH active_campaigns AS (
    SELECT 
      ac.id,
      ac.user_id,
      ac.content_id,
      p.latitude,
      p.longitude,
      jsonb_build_object(
        'id', po.id,
        'type', po.type,
        'content_url', po.content_url,
        'caption', po.caption,
        'created_at', po.created_at,
        'user', jsonb_build_object(
          'username', p.username,
          'display_name', p.display_name,
          'avatar_url', p.avatar_url
        )
      ) as content
    FROM ad_campaigns ac
    JOIN profiles p ON p.id = ac.user_id
    JOIN posts po ON po.id = ac.content_id
    WHERE 
      ac.status = 'active'
      AND ac.start_time <= now()
      AND ac.end_time > now()
      AND p.latitude IS NOT NULL 
      AND p.longitude IS NOT NULL
      AND p.latitude BETWEEN viewer_lat - 0.5 AND viewer_lat + 0.5
      AND p.longitude BETWEEN viewer_lon - 0.5 AND viewer_lon + 0.5
    LIMIT 50
  ),
  campaigns_with_distance AS (
    SELECT 
      ac.id,
      ac.user_id,
      ac.content_id,
      ac.content,
      ROUND(
        CAST(
          111.045 * sqrt(
            power(ac.latitude - viewer_lat, 2) + 
            power(ac.longitude - viewer_lon, 2)
          ) AS numeric
        ),
        3
      ) as distance
    FROM active_campaigns ac
  ),
  interaction_counts AS (
    SELECT 
      post_id,
      COUNT(*) FILTER (WHERE type = 'like') as likes_count,
      COUNT(*) FILTER (WHERE type = 'comment') as comments_count
    FROM interactions
    WHERE post_id IN (SELECT content_id FROM campaigns_with_distance)
    GROUP BY post_id
  )
  SELECT 
    cd.id as campaign_id,
    cd.user_id,
    cd.content_id,
    cd.distance,
    jsonb_set(
      cd.content,
      '{likes_count}',
      to_jsonb(COALESCE(ic.likes_count, 0))
    ) || jsonb_build_object(
      'comments_count', COALESCE(ic.comments_count, 0)
    ) as content
  FROM campaigns_with_distance cd
  LEFT JOIN interaction_counts ic ON ic.post_id = cd.content_id
  ORDER BY random()
  LIMIT 3;
$$;