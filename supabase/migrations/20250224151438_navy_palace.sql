-- Drop existing policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "users_view_own_payments" ON payments;
  DROP POLICY IF EXISTS "users_create_own_payments" ON payments;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create payment status enum if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status') THEN
    CREATE TYPE payment_status AS ENUM ('pending', 'completed', 'failed');
  END IF;
END $$;

-- Create payments table if it doesn't exist
CREATE TABLE IF NOT EXISTS payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) NOT NULL,
  payment_id text NOT NULL,
  amount integer NOT NULL,
  currency text NOT NULL DEFAULT 'INR',
  status payment_status NOT NULL DEFAULT 'pending',
  type text NOT NULL CHECK (type IN ('ad_campaign', 'badge_subscription')),
  reference_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  verified_at timestamptz,
  metadata jsonb,
  error_message text,
  error_code text,
  error_details jsonb,
  retry_count integer DEFAULT 0,
  max_retries integer DEFAULT 3,
  last_retry_at timestamptz,
  retry_status text CHECK (retry_status IN ('pending', 'retrying', 'exhausted')),
  request_id uuid DEFAULT gen_random_uuid(),
  request_timestamp timestamptz DEFAULT now(),
  request_data jsonb,
  response_data jsonb,
  signature text,
  verification_attempts integer DEFAULT 0,
  last_verification_at timestamptz,
  verified boolean DEFAULT false,
  CONSTRAINT valid_amount CHECK (amount > 0)
);

-- Enable RLS
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "users_view_own_payments"
  ON payments FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "users_create_own_payments"
  ON payments FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Create function to process payment
CREATE OR REPLACE FUNCTION process_payment(
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
  request_data jsonb;
BEGIN
  -- Validate input
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Invalid payment amount';
  END IF;

  IF p_type NOT IN ('ad_campaign', 'badge_subscription') THEN
    RAISE EXCEPTION 'Invalid payment type';
  END IF;

  -- Build request data
  request_data = jsonb_build_object(
    'amount', p_amount,
    'type', p_type,
    'reference_id', p_reference_id,
    'metadata', p_metadata
  );

  -- Create payment record
  INSERT INTO payments (
    user_id,
    payment_id,
    amount,
    type,
    reference_id,
    metadata,
    request_data,
    request_timestamp
  ) VALUES (
    p_user_id,
    p_payment_id,
    p_amount,
    p_type,
    p_reference_id,
    p_metadata,
    request_data,
    now()
  )
  RETURNING id INTO payment_record_id;

  RETURN payment_record_id;
END;
$$;

-- Create function to verify payment
CREATE OR REPLACE FUNCTION verify_payment(
  p_payment_id text,
  p_reference_id uuid,
  p_payment_type text,
  p_signature text DEFAULT NULL,
  p_response_data jsonb DEFAULT NULL
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

  -- Update verification attempt
  UPDATE payments
  SET 
    verification_attempts = verification_attempts + 1,
    last_verification_at = now(),
    signature = COALESCE(p_signature, signature),
    response_data = COALESCE(p_response_data, response_data),
    verified = true,
    status = 'completed',
    updated_at = now()
  WHERE id = v_payment.id;

  -- Update related records based on payment type
  CASE p_payment_type
    WHEN 'ad_campaign' THEN
      UPDATE ad_campaigns
      SET status = 'active'
      WHERE id = p_reference_id;
    
    WHEN 'badge_subscription' THEN
      -- No action needed as badge subscriptions are active by default
      NULL;
    
    ELSE
      RETURN false;
  END CASE;

  RETURN true;
END;
$$;

-- Create function to handle payment errors
CREATE OR REPLACE FUNCTION handle_payment_error(
  p_payment_id uuid,
  p_error_message text,
  p_error_code text DEFAULT NULL,
  p_error_details jsonb DEFAULT NULL
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
  WHERE id = p_payment_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- Update error information
  UPDATE payments
  SET 
    error_message = p_error_message,
    error_code = p_error_code,
    error_details = p_error_details,
    response_data = jsonb_build_object(
      'error', p_error_message,
      'code', p_error_code,
      'details', p_error_details,
      'timestamp', now()
    ),
    status = 'failed',
    updated_at = now()
  WHERE id = p_payment_id;

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
CREATE INDEX IF NOT EXISTS idx_payments_user ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_reference ON payments(reference_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_type ON payments(type);
CREATE INDEX IF NOT EXISTS idx_payments_payment_id ON payments(payment_id);
CREATE INDEX IF NOT EXISTS idx_payments_verification ON payments(payment_id, reference_id, type) WHERE NOT verified;
CREATE INDEX IF NOT EXISTS idx_payments_request ON payments(request_id, request_timestamp) WHERE NOT verified;