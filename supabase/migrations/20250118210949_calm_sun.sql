-- Drop the existing function
DROP FUNCTION IF EXISTS find_nearby_users;

-- Create improved function with proper grouping
CREATE OR REPLACE FUNCTION find_nearby_users(
  user_lat double precision,
  user_lon double precision,
  max_distance double precision, -- in kilometers
  hours_threshold integer -- how many hours back to look
)
RETURNS TABLE (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  account_type account_type,
  distance double precision,
  location_updated_at timestamptz
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH nearby_users AS (
    SELECT 
      p.id,
      p.username,
      p.display_name,
      p.avatar_url,
      p.account_type,
      p.location_updated_at,
      -- Haversine formula to calculate distance in kilometers
      (
        6371 * acos(
          cos(radians(user_lat)) * 
          cos(radians(p.latitude)) * 
          cos(radians(p.longitude) - radians(user_lon)) + 
          sin(radians(user_lat)) * 
          sin(radians(p.latitude))
        )
      ) as distance
    FROM profiles p
    WHERE 
      -- Exclude null locations
      p.latitude IS NOT NULL 
      AND p.longitude IS NOT NULL
      -- Only include recent updates
      AND p.location_updated_at >= (now() - (hours_threshold || ' hours')::interval)
      -- Rough distance filter using bounding box (for performance)
      AND p.latitude BETWEEN user_lat - (max_distance/111.0) AND user_lat + (max_distance/111.0)
      AND p.longitude BETWEEN user_lon - (max_distance/111.0) AND user_lon + (max_distance/111.0)
      -- Exclude the current user
      AND p.id != auth.uid()
  )
  SELECT 
    id,
    username,
    display_name,
    avatar_url,
    account_type,
    distance,
    location_updated_at
  FROM nearby_users
  WHERE distance <= max_distance
  ORDER BY distance;
END;
$$;