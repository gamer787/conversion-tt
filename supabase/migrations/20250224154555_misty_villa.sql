-- Drop existing functions if they exist
DO $$ 
BEGIN
  DROP FUNCTION IF EXISTS process_payment_v3(uuid, text, integer, text, uuid, jsonb);
  DROP FUNCTION IF EXISTS verify_payment_v3(text, uuid, text);
  DROP FUNCTION IF EXISTS handle_payment_failure_v3(uuid);
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Add razorpay_payment_id column if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'payments' AND column_name = 'razorpay_payment_id'
  ) THEN
    ALTER TABLE payments ADD COLUMN razorpay_payment_id text;
  END IF;
END $$;

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
    razorpay_payment_id,
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
  WHERE razorpay_payment_id = p_payment_id
    AND reference_id = p_reference_id
    AND type = p_payment_type;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- Update payment record
  UPDATE payments
  SET 
    status = 'completed',
    completed_at = now()
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
  SET status = 'failed'
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
CREATE INDEX IF NOT EXISTS idx_payments_user_v3 ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_reference_v3 ON payments(reference_id);
CREATE INDEX IF NOT EXISTS idx_payments_status_v3 ON payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_type_v3 ON payments(type);
CREATE INDEX IF NOT EXISTS idx_payments_razorpay_v3 ON payments(razorpay_payment_id);
CREATE INDEX IF NOT EXISTS idx_payment_logs_payment_v3 ON payment_logs(payment_id);
CREATE INDEX IF NOT EXISTS idx_payment_logs_created_v3 ON payment_logs(created_at);