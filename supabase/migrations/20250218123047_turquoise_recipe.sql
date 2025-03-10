/*
  # Add badge subscriptions support
  
  1. New Tables
    - `badge_subscriptions`
      - Tracks active badge subscriptions
      - Stores category, role, and validity period
      - Links to user profile
  
  2. Changes
    - Add subscription tracking
    - Support for monthly validity
    - Price tracking
*/

-- Create badge subscriptions table
CREATE TABLE badge_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) NOT NULL,
  category text NOT NULL,
  role text NOT NULL,
  price integer NOT NULL DEFAULT 99,
  start_date timestamptz NOT NULL DEFAULT now(),
  end_date timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT valid_dates CHECK (end_date > start_date)
);

-- Enable RLS
ALTER TABLE badge_subscriptions ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view their own subscriptions"
  ON badge_subscriptions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own subscriptions"
  ON badge_subscriptions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Create indexes
CREATE INDEX idx_badge_subscriptions_user ON badge_subscriptions(user_id);
CREATE INDEX idx_badge_subscriptions_dates ON badge_subscriptions(start_date, end_date);

-- Function to get active badge
CREATE OR REPLACE FUNCTION get_active_badge(user_id uuid)
RETURNS TABLE (
  category text,
  role text,
  days_remaining integer
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    category,
    role,
    EXTRACT(DAY FROM (end_date - CURRENT_TIMESTAMP))::integer as days_remaining
  FROM badge_subscriptions
  WHERE user_id = auth.uid()
    AND CURRENT_TIMESTAMP BETWEEN start_date AND end_date
  ORDER BY end_date DESC
  LIMIT 1;
$$;