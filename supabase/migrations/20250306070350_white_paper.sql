/*
  # Payment System Setup V3
  
  1. Tables
    - `payment_logs`: Tracks all payment-related events and status changes
      - Links to payments table
      - Stores transaction history and metadata
      - Includes event timestamps

  2. Functions
    - Process new payments
    - Verify payment status
    - Handle payment failures
    - Automatic status updates

  3. Security
    - RLS policies for payment logs
    - Secure function execution
    - User data protection
*/

-- Drop existing functions first to avoid conflicts
DROP FUNCTION IF EXISTS process_payment_v3(uuid, text, integer, text, uuid, jsonb);
DROP FUNCTION IF EXISTS verify_payment_v3(text, uuid, text);
DROP FUNCTION IF EXISTS handle_payment_failure_v3(uuid);

-- Create payment logs table if it doesn't exist
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS payment_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id uuid REFERENCES payments(id),
    event text NOT NULL,
    status payment_status NOT NULL,
    data jsonb,
    created_at timestamptz DEFAULT now() NOT NULL
  );
EXCEPTION
  WHEN duplicate_table THEN NULL;
END $$;

-- Create indexes for payment logs if they don't exist
DO $$ BEGIN
  CREATE INDEX IF NOT EXISTS idx_payment_logs_payment ON payment_logs(payment_id);
  CREATE INDEX IF NOT EXISTS idx_payment_logs_created ON payment_logs(created_at);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Function to process a new payment
CREATE FUNCTION process_payment_v3(
  user_id uuid,
  payment_id text,
  amount integer,
  type text,
  reference_id uuid,
  metadata jsonb DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_payment_id uuid;
BEGIN
  -- Insert new payment record
  INSERT INTO payments (
    id,
    user_id,
    razorpay_payment_id,
    amount,
    status,
    type,
    reference_id,
    metadata
  )
  VALUES (
    gen_random_uuid(),
    user_id,
    payment_id,
    amount,
    'processing',
    type,
    reference_id,
    metadata
  )
  RETURNING id INTO new_payment_id;

  -- Log the payment initiation
  INSERT INTO payment_logs (
    payment_id,
    event,
    status,
    data
  )
  VALUES (
    new_payment_id,
    'payment_initiated',
    'processing',
    jsonb_build_object(
      'amount', amount,
      'type', type,
      'reference_id', reference_id,
      'metadata', metadata
    )
  );
END;
$$;

-- Function to verify payment status
CREATE FUNCTION verify_payment_v3(
  payment_id text,
  reference_id uuid,
  payment_type text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  payment_record payments%ROWTYPE;
BEGIN
  -- Get payment record
  SELECT * INTO payment_record
  FROM payments
  WHERE razorpay_payment_id = payment_id
  AND type = payment_type
  AND reference_id = reference_id;

  -- Verify payment exists
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment not found';
  END IF;

  -- Update payment status
  UPDATE payments
  SET 
    status = 'completed',
    completed_at = now()
  WHERE id = payment_record.id;

  -- Log successful verification
  INSERT INTO payment_logs (
    payment_id,
    event,
    status,
    data
  )
  VALUES (
    payment_record.id,
    'payment_verified',
    'completed',
    jsonb_build_object(
      'payment_id', payment_id,
      'reference_id', reference_id,
      'type', payment_type
    )
  );

  -- Handle specific payment types
  CASE payment_type
    WHEN 'badge_subscription' THEN
      -- Activate badge subscription
      UPDATE badge_subscriptions
      SET payment_id = payment_record.id
      WHERE id = reference_id;

    WHEN 'ad_campaign' THEN
      -- Activate ad campaign
      UPDATE ad_campaigns
      SET 
        payment_id = payment_record.id,
        status = 'active',
        start_time = now(),
        end_time = now() + (duration_hours || ' hours')::interval
      WHERE id = reference_id;
  END CASE;
END;
$$;

-- Function to handle payment failures
CREATE FUNCTION handle_payment_failure_v3(
  payment_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  payment_record payments%ROWTYPE;
BEGIN
  -- Get payment record
  SELECT * INTO payment_record
  FROM payments
  WHERE id = payment_id;

  -- Verify payment exists
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment not found';
  END IF;

  -- Update payment status
  UPDATE payments
  SET status = 'failed'
  WHERE id = payment_id;

  -- Log failure
  INSERT INTO payment_logs (
    payment_id,
    event,
    status,
    data
  )
  VALUES (
    payment_id,
    'payment_failed',
    'failed',
    jsonb_build_object(
      'type', payment_record.type,
      'reference_id', payment_record.reference_id
    )
  );

  -- Handle specific payment types
  CASE payment_record.type
    WHEN 'badge_subscription' THEN
      -- Cancel badge subscription
      UPDATE badge_subscriptions
      SET cancelled_at = now()
      WHERE id = payment_record.reference_id;

    WHEN 'ad_campaign' THEN
      -- Cancel ad campaign
      UPDATE ad_campaigns
      SET status = 'pending'
      WHERE id = payment_record.reference_id;
  END CASE;
END;
$$;

-- Enable RLS on payment_logs if not already enabled
DO $$ BEGIN
  ALTER TABLE payment_logs ENABLE ROW LEVEL SECURITY;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Drop existing policy if it exists
DO $$ BEGIN
  DROP POLICY IF EXISTS "users_view_own_payment_logs_v3" ON payment_logs;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

-- Create new policy
CREATE POLICY "users_view_own_payment_logs_v3" ON payment_logs
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM payments
      WHERE payments.id = payment_logs.payment_id
      AND payments.user_id = auth.uid()
    )
  );

-- Create indexes for efficient querying if they don't exist
DO $$ BEGIN
  CREATE INDEX IF NOT EXISTS idx_payment_logs_payment_v3 ON payment_logs(payment_id);
  CREATE INDEX IF NOT EXISTS idx_payment_logs_created_v3 ON payment_logs(created_at);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;