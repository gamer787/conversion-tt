/*
  # Payment System Implementation

  1. Core Tables
    - payments: Stores payment records
    - payment_logs: Stores detailed payment activity logs
  
  2. Features
    - Robust payment tracking
    - Detailed error handling
    - Payment verification
    - Automatic status updates
    - Audit logging
*/

-- Drop existing objects in the correct order
DROP FUNCTION IF EXISTS process_payment(uuid, text, integer, text, uuid, jsonb);
DROP FUNCTION IF EXISTS verify_payment(text, text, text);
DROP FUNCTION IF EXISTS handle_payment_failure(text, text, text);
DROP TABLE IF EXISTS payment_logs CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TYPE IF EXISTS payment_status CASCADE;

-- Create payment status enum
CREATE TYPE payment_status AS ENUM ('pending', 'processing', 'completed', 'failed');

-- Create payments table
CREATE TABLE payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) NOT NULL,
  razorpay_order_id text,
  razorpay_payment_id text,
  razorpay_signature text,
  amount integer NOT NULL,
  currency text NOT NULL DEFAULT 'INR',
  status payment_status NOT NULL DEFAULT 'pending',
  type text NOT NULL CHECK (type IN ('ad_campaign', 'badge_subscription')),
  reference_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  metadata jsonb,
  CONSTRAINT valid_amount CHECK (amount > 0)
);

-- Create payment logs table for audit trail
CREATE TABLE payment_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id uuid REFERENCES payments(id) NOT NULL,
  event text NOT NULL,
  status payment_status NOT NULL,
  data jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_logs ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "users_view_own_payments"
  ON payments FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "users_create_own_payments"
  ON payments FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "users_view_own_payment_logs"
  ON payment_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM payments
      WHERE id = payment_logs.payment_id
      AND user_id = auth.uid()
    )
  );

-- Create function to process payment
CREATE FUNCTION process_payment(
  p_user_id uuid,
  p_razorpay_order_id text,
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
  payment_id uuid;
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
    razorpay_order_id,
    amount,
    type,
    reference_id,
    metadata,
    status
  ) VALUES (
    p_user_id,
    p_razorpay_order_id,
    p_amount,
    p_type,
    p_reference_id,
    p_metadata,
    'pending'
  )
  RETURNING id INTO payment_id;

  -- Log payment creation
  INSERT INTO payment_logs (
    payment_id,
    event,
    status,
    data
  ) VALUES (
    payment_id,
    'payment_created',
    'pending',
    jsonb_build_object(
      'amount', p_amount,
      'type', p_type,
      'reference_id', p_reference_id,
      'metadata', p_metadata
    )
  );

  RETURN payment_id;
END;
$$;

-- Create function to verify payment
CREATE FUNCTION verify_payment(
  p_razorpay_payment_id text,
  p_razorpay_order_id text,
  p_razorpay_signature text
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
  WHERE razorpay_order_id = p_razorpay_order_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- Update payment record
  UPDATE payments
  SET 
    status = 'completed',
    razorpay_payment_id = p_razorpay_payment_id,
    razorpay_signature = p_razorpay_signature,
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
      'razorpay_payment_id', p_razorpay_payment_id,
      'razorpay_order_id', p_razorpay_order_id,
      'razorpay_signature', p_razorpay_signature
    )
  );

  -- Update related records based on payment type
  CASE v_payment.type
    WHEN 'ad_campaign' THEN
      UPDATE ad_campaigns
      SET status = 'active'
      WHERE id = v_payment.reference_id;
    
    WHEN 'badge_subscription' THEN
      -- Badge subscriptions are active by default
      NULL;
  END CASE;

  RETURN true;
END;
$$;

-- Create function to handle payment failure
CREATE FUNCTION handle_payment_failure(
  p_razorpay_order_id text,
  p_error_code text,
  p_error_description text
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
  WHERE razorpay_order_id = p_razorpay_order_id;

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
      'error_code', p_error_code,
      'error_description', p_error_description
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
CREATE INDEX idx_payments_user ON payments(user_id);
CREATE INDEX idx_payments_order ON payments(razorpay_order_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_type ON payments(type);
CREATE INDEX idx_payment_logs_payment ON payment_logs(payment_id);
CREATE INDEX idx_payment_logs_created ON payment_logs(created_at);