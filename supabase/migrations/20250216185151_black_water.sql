/*
  # Add Ads System

  1. New Tables
    - `ad_campaigns`
      - `id` (uuid, primary key)
      - `business_id` (uuid, references profiles)
      - `content_id` (uuid, references posts)
      - `duration_hours` (integer)
      - `radius_km` (integer)
      - `price` (integer)
      - `views` (integer)
      - `status` (enum: pending, active, completed)
      - `start_time` (timestamptz)
      - `end_time` (timestamptz)
      - `created_at` (timestamptz)

  2. Functions
    - `get_visible_ads`: Returns ads visible to a user based on their location
    - `increment_ad_views`: Increments the view count for an ad

  3. Security
    - Enable RLS on `ad_campaigns` table
    - Add policies for business accounts to manage their ads
    - Add policies for users to view ads
*/

-- Create ad campaign status enum
CREATE TYPE ad_campaign_status AS ENUM ('pending', 'active', 'completed');

-- Create ad campaigns table
CREATE TABLE ad_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid REFERENCES profiles(id) NOT NULL,
  content_id uuid REFERENCES posts(id) NOT NULL,
  duration_hours integer NOT NULL,
  radius_km integer NOT NULL,
  price integer NOT NULL,
  views integer NOT NULL DEFAULT 0,
  status ad_campaign_status NOT NULL DEFAULT 'pending',
  start_time timestamptz,
  end_time timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT valid_duration CHECK (duration_hours > 0),
  CONSTRAINT valid_radius CHECK (radius_km > 0),
  CONSTRAINT valid_price CHECK (price > 0)
);

-- Enable RLS
ALTER TABLE ad_campaigns ENABLE ROW LEVEL SECURITY;

-- Create indexes for better performance
CREATE INDEX idx_ad_campaigns_business ON ad_campaigns(business_id);
CREATE INDEX idx_ad_campaigns_status ON ad_campaigns(status);
CREATE INDEX idx_ad_campaigns_active_time ON ad_campaigns(start_time, end_time) 
WHERE status = 'active';

-- Function to get visible ads for a user
CREATE OR REPLACE FUNCTION get_visible_ads(
  user_lat double precision,
  user_lon double precision
)
RETURNS TABLE (
  campaign_id uuid,
  business_id uuid,
  content_id uuid,
  distance double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH active_campaigns AS (
    -- Get all active campaigns
    SELECT 
      ac.id as campaign_id,
      ac.business_id,
      ac.content_id,
      ac.radius_km,
      p.latitude as business_lat,
      p.longitude as business_lon
    FROM ad_campaigns ac
    JOIN profiles p ON p.id = ac.business_id
    WHERE 
      ac.status = 'active'
      AND ac.start_time <= now()
      AND ac.end_time > now()
      AND p.latitude IS NOT NULL
      AND p.longitude IS NOT NULL
  )
  SELECT 
    ac.campaign_id,
    ac.business_id,
    ac.content_id,
    -- Calculate distance using Haversine formula
    (
      6371 * acos(
        cos(radians(user_lat)) * 
        cos(radians(ac.business_lat)) * 
        cos(radians(ac.business_lon) - radians(user_lon)) + 
        sin(radians(user_lat)) * 
        sin(radians(ac.business_lat))
      )
    ) as distance
  FROM active_campaigns ac
  WHERE (
    6371 * acos(
      cos(radians(user_lat)) * 
      cos(radians(ac.business_lat)) * 
      cos(radians(ac.business_lon) - radians(user_lon)) + 
      sin(radians(user_lat)) * 
      sin(radians(ac.business_lat))
    )
  ) <= ac.radius_km
  ORDER BY random(); -- Randomize order for fair distribution
END;
$$;

-- Function to increment ad views
CREATE OR REPLACE FUNCTION increment_ad_views(campaign_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

-- RLS Policies

-- Business accounts can manage their own ads
CREATE POLICY "businesses_manage_own_ads"
  ON ad_campaigns
  USING (
    business_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND account_type = 'business'
    )
  );

-- Everyone can view active ads
CREATE POLICY "users_view_active_ads"
  ON ad_campaigns FOR SELECT
  USING (
    status = 'active'
    AND start_time <= now()
    AND end_time > now()
  );

-- Function to update campaign status based on time
CREATE OR REPLACE FUNCTION update_campaign_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Set campaign as completed if end_time has passed
  UPDATE ad_campaigns
  SET status = 'completed'
  WHERE status = 'active'
  AND end_time <= now();
  
  RETURN NULL;
END;
$$;

-- Create trigger to update campaign status
CREATE TRIGGER update_campaign_status_trigger
  AFTER INSERT OR UPDATE ON ad_campaigns
  FOR EACH STATEMENT
  EXECUTE FUNCTION update_campaign_status();