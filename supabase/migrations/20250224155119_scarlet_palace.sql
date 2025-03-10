-- Create payment_logs table if it doesn't exist
DO $$ 
BEGIN
  CREATE TABLE IF NOT EXISTS payment_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id uuid REFERENCES payments(id) NOT NULL,
    event text NOT NULL,
    status text NOT NULL,
    data jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
  );
EXCEPTION
  WHEN duplicate_table THEN
    NULL;
END $$;

-- Enable RLS on payment_logs
ALTER TABLE payment_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "users_view_own_payment_logs_v3" ON payment_logs;

-- Create RLS policy for payment_logs
CREATE POLICY "users_view_own_payment_logs_v3"
  ON payment_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM payments
      WHERE id = payment_logs.payment_id
      AND user_id = auth.uid()
    )
  );

-- Create function to process payment
CREATE OR REPLACE FUNCTION process_payment_v3(
  p_user_id uuid,
  p_payment_id text,
  p_amount integer,
  p_type text,
  p_reference_id uuid,
  p_metadata jsonb DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  payment_record_id uuid;
BEGIN
  -- Validate input
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Invalid payment amount';
  END IF;

  IF p_type NOT IN ('ad_campaign', 'badge_subscription') THEN
    RAISE EXCEPTION 'Invalid payment type';
  END IF;

  -- Create payment record
  INSERT INTO payments (
    user_id,
    payment_id,
    amount,
    type,
    reference_id,
    metadata,
    status
  ) VALUES (
    p_user_id,
    p_payment_id,
    p_amount,
    p_type,
    p_reference_id,
    p_metadata,
    'pending'
  )
  RETURNING id INTO payment_record_id;

  -- Log payment creation
  INSERT INTO payment_logs (
    payment_id,
    event,
    status,
    data
  ) VALUES (
    payment_record_id,
    'payment_created',
    'pending',
    jsonb_build_object(
      'amount', p_amount,
      'type', p_type,
      'reference_id', p_reference_id,
      'metadata', p_metadata
    )
  );

  RETURN payment_record_id;
END;
$$;

-- Create function to verify payment
CREATE OR REPLACE FUNCTION verify_payment_v3(
  p_payment_id text,
  p_reference_id uuid,
  p_payment_type text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payment payments;
BEGIN
  -- Get payment record
  SELECT * INTO v_payment
  FROM payments
  WHERE payment_id = p_payment_id
    AND reference_id = p_reference_id
    AND type = p_payment_type;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- Update payment record
  UPDATE payments
  SET 
    status = 'completed',
    updated_at = now()
  WHERE id = v_payment.id;

  -- Log payment verification
  INSERT INTO payment_logs (
    payment_id,
    event,
    status,
    data
  ) VALUES (
    v_payment.id,
    'payment_verified',
    'completed',
    jsonb_build_object(
      'payment_id', p_payment_id,
      'reference_id', p_reference_id,
      'type', p_payment_type
    )
  );

  -- Update related records based on payment type
  CASE p_payment_type
    WHEN 'ad_campaign' THEN
      UPDATE ad_campaigns
      SET status = 'active'
      WHERE id = p_reference_id;
    
    WHEN 'badge_subscription' THEN
      -- Badge subscriptions are active by default
      NULL;
  END CASE;

  RETURN true;
END;
$$;

-- Create function to handle payment failure
CREATE OR REPLACE FUNCTION handle_payment_failure_v3(payment_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payment payments;
BEGIN
  -- Get payment record
  SELECT * INTO v_payment
  FROM payments
  WHERE id = payment_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- Update payment status
  UPDATE payments
  SET 
    status = 'failed',
    updated_at = now()
  WHERE id = v_payment.id;

  -- Log payment failure
  INSERT INTO payment_logs (
    payment_id,
    event,
    status,
    data
  ) VALUES (
    v_payment.id,
    'payment_failed',
    'failed',
    jsonb_build_object(
      'timestamp', now()
    )
  );

  -- Update related records based on payment type
  CASE v_payment.type
    WHEN 'ad_campaign' THEN
      UPDATE ad_campaigns
      SET status = 'pending'
      WHERE id = v_payment.reference_id;
    
    WHEN 'badge_subscription' THEN
      UPDATE badge_subscriptions
      SET cancelled_at = now()
      WHERE id = v_payment.reference_id;
  END CASE;

  RETURN true;
END;
$$;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_payment_logs_payment_v3 ON payment_logs(payment_id);
CREATE INDEX IF NOT EXISTS idx_payment_logs_created_v3 ON payment_logs(created_at);