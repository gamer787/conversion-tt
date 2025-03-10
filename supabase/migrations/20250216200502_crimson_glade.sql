/*
  # Create price tiers table and add initial data

  1. New Tables
    - `ad_price_tiers`
      - `id` (uuid, primary key)
      - `duration_hours` (integer)
      - `radius_km` (integer)
      - `price` (integer)
      - `created_at` (timestamptz)

  2. Changes
    - Add price_tier_id reference to ad_campaigns table
    - Insert predefined price tiers
*/

-- Create price tiers table
CREATE TABLE IF NOT EXISTS ad_price_tiers (
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

-- Enable RLS
ALTER TABLE ad_price_tiers ENABLE ROW LEVEL SECURITY;

-- Add price tier reference to ad_campaigns
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'ad_campaigns' AND column_name = 'price_tier_id'
  ) THEN
    ALTER TABLE ad_campaigns
    ADD COLUMN price_tier_id uuid REFERENCES ad_price_tiers(id);
  END IF;
END $$;

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
  (24, 100, 900),  -- 24 hours, 100km radius
  
  -- State-wide reach
  (1, 500, 999),    -- 1 hour, 500km radius
  (6, 500, 1124),   -- 6 hours, 500km radius
  (12, 500, 1234),  -- 12 hours, 500km radius
  (24, 500, 1300)   -- 24 hours, 500km radius
ON CONFLICT (duration_hours, radius_km) 
DO UPDATE SET price = EXCLUDED.price;

-- Create RLS policy for viewing price tiers
CREATE POLICY "price_tiers_select_policy"
  ON ad_price_tiers FOR SELECT
  USING (true);

-- Create index for price tier lookups
CREATE INDEX IF NOT EXISTS idx_price_tiers_settings 
ON ad_price_tiers(duration_hours, radius_km);