-- Drop existing policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "users_view_own_payments" ON payments;
  DROP POLICY IF EXISTS "users_create_own_payments" ON payments;
  DROP POLICY IF EXISTS "users_view_own_payment_logs" ON payment_logs;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Drop existing functions if they exist
DO $$ 
BEGIN
  DROP FUNCTION IF EXISTS process_payment(uuid, text, integer, text, uuid, jsonb);
  DROP FUNCTION IF EXISTS verify_payment(text, text, text);
  DROP FUNCTION IF EXISTS handle_payment_failure(text, text, text);
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create RLS policies
CREATE POLICY "users_view_own_payments_new"
  ON payments FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "users_create_own_payments_new"
  ON payments FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "users_view_own_payment_logs_new"
  ON payment_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM payments
      WHERE id = payment_logs.payment_id
      AND user_id = auth.uid()
    )
  );

-- Create function to process payment
CREATE OR REPLACE FUNCTION process_payment_v2(
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
CREATE OR REPLACE FUNCTION verify_payment_v2(
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
CREATE OR REPLACE FUNCTION handle_payment_failure_v2(
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