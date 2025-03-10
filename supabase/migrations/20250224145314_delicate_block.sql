/*
  # Add Payment Validation Functions

  1. New Functions
    - `validate_payment`: Validates payment details before processing
    - `handle_payment_failure`: Handles failed payments
    
  2. Triggers
    - Automatically handles payment status changes
*/

-- Create function to validate payment details
CREATE OR REPLACE FUNCTION validate_payment(
  p_amount integer,
  p_type text,
  p_reference_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Validate amount
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Invalid payment amount';
  END IF;

  -- Validate payment type
  IF p_type NOT IN ('ad_campaign', 'badge_subscription') THEN
    RAISE EXCEPTION 'Invalid payment type';
  END IF;

  -- Validate reference exists
  IF p_type = 'ad_campaign' THEN
    IF NOT EXISTS (SELECT 1 FROM ad_campaigns WHERE id = p_reference_id) THEN
      RAISE EXCEPTION 'Invalid campaign reference';
    END IF;
  ELSIF p_type = 'badge_subscription' THEN
    IF NOT EXISTS (SELECT 1 FROM badge_subscriptions WHERE id = p_reference_id) THEN
      RAISE EXCEPTION 'Invalid subscription reference';
    END IF;
  END IF;

  RETURN true;
END;
$$;

-- Create function to handle payment failure
CREATE OR REPLACE FUNCTION handle_payment_failure(
  p_payment_id uuid
)
RETURNS void
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
    RAISE EXCEPTION 'Payment not found';
  END IF;

  -- Update payment status
  UPDATE payments
  SET 
    status = 'failed',
    updated_at = now()
  WHERE id = p_payment_id;

  -- Handle related records
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
END;
$$;

-- Create trigger to handle payment status changes
CREATE OR REPLACE FUNCTION handle_payment_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Handle status changes
  IF NEW.status = 'failed' AND OLD.status != 'failed' THEN
    PERFORM handle_payment_failure(NEW.id);
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger
CREATE TRIGGER payment_status_change_trigger
  AFTER UPDATE OF status ON payments
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION handle_payment_status_change();

-- Add updated_at column to payments if it doesn't exist
ALTER TABLE payments
ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Create trigger for updated_at
CREATE TRIGGER update_payments_updated_at
  BEFORE UPDATE ON payments
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();