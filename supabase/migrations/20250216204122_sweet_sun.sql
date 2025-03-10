/*
  # Rebuild Ads System

  1. New Tables
    - `ad_price_tiers`: Predefined pricing packages
    - `ad_campaigns`: User ad campaigns
    
  2. Changes
    - Simplified schema
    - Optimized queries
    - Better indexing
    
  3. Security
    - RLS policies for access control
*/

-- Drop existing tables if they exist
DROP TABLE IF EXISTS ad_campaigns CASCADE;
DROP TABLE IF EXISTS ad_price_tiers CASCADE;

-- Create ad_price_tiers table
CREATE TABLE ad_price_tiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  duration_hours integer NOT NULL,
  radius_km integer NOT NULL,
  price integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT valid_duration CHECK (duration_hours > 0),
  CONSTRAINT valid_radius CHECK (radius_km > 0),
  CONSTRAINT valid_price CHECK (price > 0),
  CONSTRAINT unique_duration_radius UNIQUE (duration_hours, radius_km)
);

-- Create ad_campaigns table
CREATE TABLE ad_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) NOT NULL,
  content_id uuid REFERENCES posts(id) NOT NULL,
  price_tier_id uuid REFERENCES ad_price_tiers(id) NOT NULL,
  duration_hours integer NOT NULL,
  radius_km integer NOT NULL,
  price integer NOT NULL,
  views integer NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('pending', 'active', 'completed')),
  start_time timestamptz,
  end_time timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT valid_campaign_duration CHECK (duration_hours > 0),
  CONSTRAINT valid_campaign_radius CHECK (radius_km > 0),
  CONSTRAINT valid_campaign_price CHECK (price > 0),
  CONSTRAINT valid_campaign_times CHECK (start_time < end_time)
);

-- Enable RLS
ALTER TABLE ad_price_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE ad_campaigns ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "price_tiers_viewable_by_everyone"
  ON ad_price_tiers FOR SELECT
  USING (true);

CREATE POLICY "users_manage_own_ads"
  ON ad_campaigns
  USING (user_id = auth.uid());

CREATE POLICY "users_view_active_ads"
  ON ad_campaigns FOR SELECT
  USING (
    status = 'active'
    AND start_time <= now()
    AND end_time > now()
  );

-- Create optimized function for getting visible ads
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
  WITH active_campaigns AS (
    SELECT 
      ac.id,
      ac.user_id,
      ac.content_id,
      p.latitude,
      p.longitude
    FROM ad_campaigns ac
    JOIN profiles p ON p.id = ac.user_id
    WHERE 
      ac.status = 'active'
      AND ac.start_time <= now()
      AND ac.end_time > now()
      AND p.latitude IS NOT NULL 
      AND p.longitude IS NOT NULL
      -- Pre-filter by bounding box
      AND p.latitude BETWEEN viewer_lat - 0.5 AND viewer_lat + 0.5
      AND p.longitude BETWEEN viewer_lon - 0.5 AND viewer_lon + 0.5
    LIMIT 50
  )
  SELECT 
    ac.id as campaign_id,
    ac.user_id,
    ac.content_id,
    -- Simple distance calculation
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
  ORDER BY random()
  LIMIT 3;
$$;

-- Create function to increment ad views
CREATE OR REPLACE FUNCTION increment_ad_views(campaign_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE ad_campaigns
  SET views = views + 1
  WHERE id = campaign_id
  AND status = 'active'
  AND start_time <= now()
  AND end_time > now();
END;
$$;

-- Create optimized indexes
CREATE INDEX IF NOT EXISTS idx_ad_campaigns_status 
ON ad_campaigns(status, start_time, end_time)
WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_ad_campaigns_user 
ON ad_campaigns(user_id, status);

CREATE INDEX IF NOT EXISTS idx_ad_price_tiers_settings 
ON ad_price_tiers(duration_hours, radius_km);

-- Insert predefined price tiers
INSERT INTO ad_price_tiers (duration_hours, radius_km, price)
VALUES
  -- Local reach
  (1, 5, 99),    -- 1 hour, 5km radius
  (6, 5, 224),   -- 6 hours, 5km radius
  (12, 5, 334),  -- 12 hours, 5km radius
  (24, 5, 400),  -- 24 hours, 5km radius
  
  -- Medium reach
  (1, 25, 249),   -- 1 hour, 25km radius
  (6, 25, 374),   -- 6 hours, 25km radius
  (12, 25, 484),  -- 12 hours, 25km radius
  (24, 25, 550),  -- 24 hours, 25km radius
  
  -- Wide reach
  (1, 50, 399),   -- 1 hour, 50km radius
  (6, 50, 524),   -- 6 hours, 50km radius
  (12, 50, 634),  -- 12 hours, 50km radius
  (24, 50, 700),  -- 24 hours, 50km radius
  
  -- Regional reach
  (1, 100, 599),   -- 1 hour, 100km radius
  (6, 100, 724),   -- 6 hours, 100km radius
  (12, 100, 834),  -- 12 hours, 100km radius
  (24, 100, 900)   -- 24 hours, 100km radius
ON CONFLICT (duration_hours, radius_km) 
DO UPDATE SET price = EXCLUDED.price;