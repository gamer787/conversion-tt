/*
  # Add Payment Retry Handling

  1. New Functions
    - `handle_payment_retry`: Manages payment retry attempts
    - `cleanup_failed_payments`: Cleans up failed payment records
    
  2. New Columns
    - Add retry tracking to payments table
*/

-- Add retry tracking columns to payments table
ALTER TABLE payments
ADD COLUMN IF NOT EXISTS retry_count integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_retry_at timestamptz,
ADD COLUMN IF NOT EXISTS max_retries integer DEFAULT 3;

-- Create function to handle payment retry
CREATE OR REPLACE FUNCTION handle_payment_retry(
  p_payment_id uuid
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

  -- Check if max retries reached
  IF v_payment.retry_count >= v_payment.max_retries THEN
    -- Mark as permanently failed
    UPDATE payments
    SET 
      status = 'failed',
      updated_at = now()
    WHERE id = p_payment_id;
    
    -- Handle related records
    PERFORM handle_payment_failure(p_payment_id);
    RETURN false;
  END IF;

  -- Update retry count and timestamp
  UPDATE payments
  SET 
    retry_count = retry_count + 1,
    last_retry_at = now(),
    updated_at = now()
  WHERE id = p_payment_id;

  RETURN true;
END;
$$;

-- Create function to clean up old failed payments
CREATE OR REPLACE FUNCTION cleanup_failed_payments()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Archive payments that have failed all retries
  WITH failed_payments AS (
    SELECT id
    FROM payments
    WHERE status = 'failed'
      AND retry_count >= max_retries
      AND updated_at < now() - interval '30 days'
  )
  UPDATE payments
  SET metadata = jsonb_set(
    COALESCE(metadata, '{}'::jsonb),
    '{archived}',
    'true'
  )
  WHERE id IN (SELECT id FROM failed_payments);
END;
$$;

-- Create index for retry tracking
CREATE INDEX IF NOT EXISTS idx_payments_retry 
ON payments(status, retry_count, last_retry_at)
WHERE status = 'pending' AND retry_count < max_retries;