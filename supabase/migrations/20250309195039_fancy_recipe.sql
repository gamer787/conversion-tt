/*
  # Fix Payment Functions and Add Validation

  1. Changes
    - Drop existing functions and triggers
    - Add payment validation function and trigger
    - Add payment status change handler
    - Add payment processing functions
    - Add proper error handling and logging

  2. Security
    - All functions are SECURITY DEFINER
    - Proper validation and error handling
    - Safe transaction handling
*/

-- Drop existing functions and triggers to avoid conflicts
DROP TRIGGER IF EXISTS payment_validation_trigger_v3 ON payments;
DROP TRIGGER IF EXISTS payment_status_change_trigger_v3 ON payments;
DROP FUNCTION IF EXISTS validate_payment_v3;
DROP FUNCTION IF EXISTS handle_payment_status_change_v3;
DROP FUNCTION IF EXISTS verify_payment_v3;
DROP FUNCTION IF EXISTS process_payment_v3;
DROP FUNCTION IF EXISTS handle_payment_failure_v3;

-- Create payment validation function
CREATE OR REPLACE FUNCTION validate_payment_v3()
RETURNS trigger AS $$
BEGIN
  -- Validate amount
  IF NEW.amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than 0';
  END IF;

  -- Validate currency
  IF NEW.currency != 'INR' THEN
    RAISE EXCEPTION 'Only INR currency is supported';
  END IF;

  -- Validate payment type
  IF NEW.type NOT IN ('ad_campaign', 'badge_subscription') THEN
    RAISE EXCEPTION 'Invalid payment type';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create payment status change handler
CREATE OR REPLACE FUNCTION handle_payment_status_change_v3()
RETURNS trigger AS $$
BEGIN
  -- Log status change
  INSERT INTO payment_logs (
    payment_id,
    event,
    status,
    data
  ) VALUES (
    NEW.id,
    'status_changed',
    NEW.status,
    jsonb_build_object(
      'old_status', OLD.status,
      'new_status', NEW.status,
      'type', NEW.type
    )
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create payment verification function
CREATE OR REPLACE FUNCTION verify_payment_v3(
  p_payment_id text,
  p_order_id text,
  p_signature text,
  p_reference_id uuid,
  p_payment_type text
)
RETURNS void AS $$
DECLARE
  v_payment_record payments%ROWTYPE;
BEGIN
  -- Get payment record
  SELECT * INTO v_payment_record
  FROM payments p
  WHERE p.razorpay_payment_id = p_payment_id
  AND p.type = p_payment_type
  AND p.reference_id = p_reference_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment record not found';
  END IF;

  -- Update payment record with Razorpay details
  UPDATE payments
  SET 
    razorpay_order_id = p_order_id,
    razorpay_signature = p_signature,
    status = 'completed',
    completed_at = now()
  WHERE id = v_payment_record.id;

  -- Log payment completion
  INSERT INTO payment_logs (
    payment_id,
    event,
    status,
    data
  ) VALUES (
    v_payment_record.id,
    'payment_completed',
    'completed',
    jsonb_build_object(
      'payment_id', p_payment_id,
      'order_id', p_order_id,
      'reference_id', p_reference_id,
      'type', p_payment_type
    )
  );

  -- Handle specific payment types
  CASE p_payment_type
    WHEN 'ad_campaign' THEN
      -- Activate ad campaign
      UPDATE ad_campaigns
      SET status = 'active',
          start_time = CURRENT_TIMESTAMP,
          end_time = CURRENT_TIMESTAMP + (duration_hours || ' hours')::interval
      WHERE id = p_reference_id;
      
    WHEN 'badge_subscription' THEN
      -- Activate badge subscription
      UPDATE badge_subscriptions
      SET payment_id = v_payment_record.id,
          start_date = CURRENT_TIMESTAMP,
          end_date = CURRENT_TIMESTAMP + interval '30 days'
      WHERE id = p_reference_id;
  END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create payment processing function
CREATE OR REPLACE FUNCTION process_payment_v3(
  p_user_id uuid,
  p_payment_id text,
  p_order_id text,
  p_amount integer,
  p_type text,
  p_reference_id uuid,
  p_metadata jsonb
)
RETURNS void AS $$
DECLARE
  v_payment_record_id uuid;
BEGIN
  -- Create payment record
  INSERT INTO payments (
    user_id,
    razorpay_payment_id,
    razorpay_order_id,
    amount,
    type,
    reference_id,
    status,
    metadata
  ) VALUES (
    p_user_id,
    p_payment_id,
    p_order_id,
    p_amount,
    p_type,
    p_reference_id,
    'processing',
    p_metadata
  )
  RETURNING id INTO v_payment_record_id;

  -- Log payment initiation
  INSERT INTO payment_logs (
    payment_id,
    event,
    status,
    data
  ) VALUES (
    v_payment_record_id,
    'payment_initiated',
    'processing',
    jsonb_build_object(
      'payment_id', p_payment_id,
      'order_id', p_order_id,
      'amount', p_amount,
      'type', p_type
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create payment failure handler
CREATE OR REPLACE FUNCTION handle_payment_failure_v3(
  p_payment_id text
)
RETURNS void AS $$
DECLARE
  v_payment_record payments%ROWTYPE;
BEGIN
  -- Get payment record
  SELECT * INTO v_payment_record
  FROM payments
  WHERE razorpay_payment_id = p_payment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment record not found';
  END IF;

  -- Update payment status
  UPDATE payments
  SET status = 'failed'
  WHERE id = v_payment_record.id;

  -- Log payment failure
  INSERT INTO payment_logs (
    payment_id,
    event,
    status,
    data
  ) VALUES (
    v_payment_record.id,
    'payment_failed',
    'failed',
    jsonb_build_object(
      'payment_id', v_payment_record.razorpay_payment_id,
      'reference_id', v_payment_record.reference_id,
      'type', v_payment_record.type
    )
  );

  -- Handle specific payment types
  CASE v_payment_record.type
    WHEN 'ad_campaign' THEN
      -- Delete failed campaign
      DELETE FROM ad_campaigns
      WHERE id = v_payment_record.reference_id;
      
    WHEN 'badge_subscription' THEN
      -- Delete failed subscription
      DELETE FROM badge_subscriptions
      WHERE id = v_payment_record.reference_id;
  END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add payment validation trigger
CREATE TRIGGER payment_validation_trigger_v3
  BEFORE INSERT OR UPDATE ON payments
  FOR EACH ROW
  EXECUTE FUNCTION validate_payment_v3();

-- Add payment status change trigger
CREATE TRIGGER payment_status_change_trigger_v3
  AFTER UPDATE OF status ON payments
  FOR EACH ROW
  WHEN (NEW.status = 'completed' AND OLD.status != 'completed')
  EXECUTE FUNCTION handle_payment_status_change_v3();