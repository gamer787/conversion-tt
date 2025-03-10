/*
  # Add unique constraint to price tiers

  1. Changes
    - Add unique constraint on duration_hours and radius_km
    - Insert predefined price tiers with proper conflict handling

  2. Indexes
    - Add index for price tier settings lookup
*/

-- Add unique constraint to price tiers
ALTER TABLE ad_price_tiers
ADD CONSTRAINT unique_duration_radius UNIQUE (duration_hours, radius_km);

-- Insert predefined price tiers with proper conflict handling
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

-- Create index for price tier lookups
CREATE INDEX IF NOT EXISTS idx_price_tiers_settings 
ON ad_price_tiers(duration_hours, radius_km);