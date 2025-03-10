/*
  # Add Payment Error Handling

  1. New Columns
    - Add error tracking columns to payments table
    - Add retry status tracking
    
  2. New Functions
    - `handle_payment_error`: Manages payment error tracking and retry logic
    - `get_payment_status`: Gets detailed payment status with error info
*/

-- Add error tracking columns to payments table
ALTER TABLE payments
ADD COLUMN IF NOT EXISTS error_message text,
ADD COLUMN IF NOT EXISTS error_code text,
ADD COLUMN IF NOT EXISTS error_details jsonb,
ADD COLUMN IF NOT EXISTS retry_status text CHECK (retry_status IN ('pending', 'retrying', 'exhausted'));

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
  v_should_retry boolean;
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

-- Create function to get payment status with error details
CREATE OR REPLACE FUNCTION get_payment_status(
  p_payment_id uuid
)
RETURNS TABLE (
  status payment_status,
  retry_status text,
  retry_count integer,
  max_retries integer,
  error_message text,
  error_code text,
  error_details jsonb,
  last_retry_at timestamptz,
  next_retry_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    status,
    retry_status,
    retry_count,
    max_retries,
    error_message,
    error_code,
    error_details,
    last_retry_at,
    CASE
      WHEN retry_count < max_retries AND status = 'pending' 
      THEN last_retry_at + (interval '1 second' * power(2, retry_count))
      ELSE NULL
    END as next_retry_at
  FROM payments
  WHERE id = p_payment_id
  AND (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM ad_campaigns
      WHERE payment_id = p_payment_id
      AND user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM badge_subscriptions
      WHERE payment_id = p_payment_id
      AND user_id = auth.uid()
    )
  );
$$;

-- Create index for error tracking
CREATE INDEX IF NOT EXISTS idx_payments_error_status 
ON payments(status, retry_status, retry_count)
WHERE status = 'pending' AND retry_status = 'pending';

-- Create function to automatically retry failed payments
CREATE OR REPLACE FUNCTION retry_pending_payments()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
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

  -- Process retries using a cursor instead of a loop
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