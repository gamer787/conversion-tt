/*
  # Payment System Improvements

  1. New Columns
    - Add payment verification columns
    - Add request tracking columns
    - Add response tracking columns
    
  2. Functions
    - Improved payment processing with retry logic
    - Better error handling and tracking
    - Payment verification with signature validation
*/

-- Add payment verification and tracking columns
ALTER TABLE payments
ADD COLUMN IF NOT EXISTS request_id uuid DEFAULT gen_random_uuid(),
ADD COLUMN IF NOT EXISTS request_timestamp timestamptz DEFAULT now(),
ADD COLUMN IF NOT EXISTS request_data jsonb,
ADD COLUMN IF NOT EXISTS response_data jsonb,
ADD COLUMN IF NOT EXISTS signature text,
ADD COLUMN IF NOT EXISTS verification_attempts integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_verification_at timestamptz,
ADD COLUMN IF NOT EXISTS verified boolean DEFAULT false;

-- Create function to process payment with improved error handling
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

  -- Create payment record with request tracking
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

-- Create function to verify payment with signature validation
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

-- Create function to handle payment errors with detailed tracking
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
  v_should_retry boolean;
BEGIN
  -- Get payment record
  SELECT * INTO v_payment
  FROM payments
  WHERE id = p_payment_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- Update error information with response tracking
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
    updated_at = now(),
    retry_status = CASE
      WHEN retry_count >= max_retries THEN 'exhausted'
      ELSE 'pending'
    END
  WHERE id = p_payment_id;

  -- Determine if we should retry
  v_should_retry := v_payment.retry_count < v_payment.max_retries;

  IF v_should_retry THEN
    -- Attempt retry
    RETURN handle_payment_retry(p_payment_id);
  ELSE
    -- Mark as failed if retries exhausted
    UPDATE payments
    SET 
      status = 'failed',
      retry_status = 'exhausted',
      updated_at = now()
    WHERE id = p_payment_id;
    
    -- Handle failure consequences
    PERFORM handle_payment_failure(p_payment_id);
    RETURN false;
  END IF;
END;
$$;

-- Create function to process pending retries
CREATE OR REPLACE FUNCTION process_pending_retries()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Update status for payments that need retry
  UPDATE payments
  SET retry_status = 'retrying'
  WHERE status = 'pending'
    AND retry_status = 'pending'
    AND retry_count < max_retries
    AND (
      last_retry_at IS NULL 
      OR last_retry_at < now() - (interval '1 second' * power(2, retry_count))
    );

  -- Process retries
  UPDATE payments
  SET retry_status = 'pending'
  WHERE retry_status = 'retrying'
  AND id IN (
    SELECT id
    FROM payments
    WHERE retry_status = 'retrying'
    FOR UPDATE SKIP LOCKED
  )
  RETURNING id, handle_payment_retry(id);
END;
$$;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_payments_verification 
ON payments(payment_id, reference_id, type)
WHERE NOT verified;

CREATE INDEX IF NOT EXISTS idx_payments_request 
ON payments(request_id, request_timestamp)
WHERE NOT verified;