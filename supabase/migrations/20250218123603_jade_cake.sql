-- Drop existing policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Users can view their own subscriptions" ON badge_subscriptions;
  DROP POLICY IF EXISTS "Users can create their own subscriptions" ON badge_subscriptions;
  DROP POLICY IF EXISTS "Users can update their own subscriptions" ON badge_subscriptions;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Add cancelled_at column
ALTER TABLE badge_subscriptions
ADD COLUMN IF NOT EXISTS cancelled_at timestamptz;

-- Create indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_badge_subscriptions_cancelled 
ON badge_subscriptions(cancelled_at) 
WHERE cancelled_at IS NOT NULL;

-- Create or replace RLS policies
CREATE POLICY "Users can view their own subscriptions"
  ON badge_subscriptions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own subscriptions"
  ON badge_subscriptions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own subscriptions"
  ON badge_subscriptions FOR UPDATE
  USING (auth.uid() = user_id);

-- Drop existing function
DROP FUNCTION IF EXISTS get_active_badge;

-- Create or replace function with subscription_id
CREATE OR REPLACE FUNCTION get_active_badge(user_id uuid)
RETURNS TABLE (
  category text,
  role text,
  days_remaining integer,
  subscription_id uuid
) 
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    category,
    role,
    EXTRACT(DAY FROM (end_date - CURRENT_TIMESTAMP))::integer as days_remaining,
    id as subscription_id
  FROM badge_subscriptions
  WHERE user_id = auth.uid()
    AND CURRENT_TIMESTAMP BETWEEN start_date AND end_date
    AND cancelled_at IS NULL
  ORDER BY end_date DESC
  LIMIT 1;
$$;