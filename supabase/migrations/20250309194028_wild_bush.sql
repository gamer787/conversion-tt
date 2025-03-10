/*
  # Payment System Migration Fix

  1. New Tables
    - `payments`: Core payment information with strict validation
    - `payment_logs`: Audit trail for payment events

  2. Security
    - RLS policies with proper checks
    - Strict validation constraints
    - Secure payment processing functions

  3. Changes
    - Fixed ambiguous column references
    - Improved payment validation
    - Enhanced payment tracking
*/

-- Create payment_status type if not exists
DO $$ BEGIN
  CREATE TYPE payment_status AS ENUM ('pending', 'processing', 'completed', 'failed');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Drop existing trigger first
DROP TRIGGER IF EXISTS payment_validation_trigger_20250309 ON payments;

-- Drop existing functions
DROP FUNCTION IF EXISTS process_payment_v3(uuid, text, integer, text, uuid, jsonb);
DROP FUNCTION IF EXISTS verify_payment_v3(text, uuid, text);
DROP FUNCTION IF EXISTS handle_payment_failure_v3(uuid);
DROP FUNCTION IF EXISTS validate_payment();

-- Drop existing policies
DO $$ BEGIN
  DROP POLICY IF EXISTS users_create_own_payments_policy_20250309 ON payments;
  DROP POLICY IF EXISTS users_view_own_payments_policy_20250309 ON payments;
  DROP POLICY IF EXISTS users_view_own_payment_logs_new ON payment_logs;
EXCEPTION
  WHEN undefined_object THEN null;
END $$;

-- Payments table
CREATE TABLE IF NOT EXISTS payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id),
  razorpay_order_id text,
  razorpay_payment_id text,
  razorpay_signature text,
  amount integer NOT NULL CHECK (amount > 0),
  currency text NOT NULL DEFAULT 'INR' CHECK (currency = 'INR'),
  status payment_status NOT NULL DEFAULT 'pending',
  type text NOT NULL CHECK (type IN ('ad_campaign', 'badge_subscription')),
  reference_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  metadata jsonb
);

-- Payment logs table for audit trail
CREATE TABLE IF NOT EXISTS payment_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id uuid NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
  event text NOT NULL,
  status payment_status NOT NULL,
  data jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_payments_user_v3 ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_status_v3 ON payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_type_v3 ON payments(type);
CREATE INDEX IF NOT EXISTS idx_payments_reference_v3 ON payments(reference_id);
CREATE INDEX IF NOT EXISTS idx_payments_razorpay_v3 ON payments(razorpay_payment_id);

CREATE INDEX IF NOT EXISTS idx_payment_logs_payment_v3 ON payment_logs(payment_id);
CREATE INDEX IF NOT EXISTS idx_payment_logs_created_v3 ON payment_logs(created_at);

-- Enable RLS
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_logs ENABLE ROW LEVEL SECURITY;

-- Create validation trigger function
CREATE OR REPLACE FUNCTION validate_payment()
RETURNS trigger AS $$
BEGIN
  -- Validate amount
  IF NEW.amount <= 0 THEN
    RAISE EXCEPTION 'Payment amount must be greater than 0';
  END IF;

  -- Validate currency
  IF NEW.currency != 'INR' THEN
    RAISE EXCEPTION 'Only INR currency is supported';
  END IF;

  -- Validate payment type
  IF NEW.type NOT IN ('ad_campaign', 'badge_subscription') THEN
    RAISE EXCEPTION 'Invalid payment type';
  END IF;

  -- Validate reference_id exists
  IF NEW.type = 'ad_campaign' AND NOT EXISTS (
    SELECT 1 FROM ad_campaigns WHERE id = NEW.reference_id
  ) THEN
    RAISE EXCEPTION 'Invalid ad campaign reference';
  END IF;

  IF NEW.type = 'badge_subscription' AND NOT EXISTS (
    SELECT 1 FROM badge_subscriptions WHERE id = NEW.reference_id
  ) THEN
    RAISE EXCEPTION 'Invalid badge subscription reference';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create validation trigger
CREATE TRIGGER payment_validation_trigger_20250309
  BEFORE INSERT OR UPDATE ON payments
  FOR EACH ROW
  EXECUTE FUNCTION validate_payment();

-- RLS Policies
CREATE POLICY users_create_own_payments_policy_20250309 ON payments
  FOR INSERT TO public
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY users_view_own_payments_policy_20250309 ON payments
  FOR SELECT TO public
  USING (auth.uid() = user_id);

CREATE POLICY users_view_own_payment_logs_new ON payment_logs
  FOR SELECT TO public
  USING (EXISTS (
    SELECT 1 FROM payments p
    WHERE p.id = payment_logs.payment_id 
    AND p.user_id = auth.uid()
  ));

-- Payment Processing Functions
CREATE OR REPLACE FUNCTION process_payment_v3(
  user_id uuid,
  payment_id text,
  amount integer,
  type text,
  reference_id uuid,
  metadata jsonb
)
RETURNS void AS $$
DECLARE
  payment_record_id uuid;
BEGIN
  -- Create payment record
  INSERT INTO payments (
    user_id,
    razorpay_payment_id,
    amount,
    type,
    reference_id,
    status,
    metadata
  ) VALUES (
    user_id,
    payment_id,
    amount,
    type,
    reference_id,
    'processing',
    metadata
  )
  RETURNING id INTO payment_record_id;

  -- Log payment initiation
  INSERT INTO payment_logs (
    payment_id,
    event,
    status,
    data
  ) VALUES (
    payment_record_id,
    'payment_initiated',
    'processing',
    jsonb_build_object(
      'payment_id', payment_id,
      'amount', amount,
      'type', type
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Payment Verification Function
CREATE OR REPLACE FUNCTION verify_payment_v3(
  payment_id text,
  reference_id uuid,
  payment_type text
)
RETURNS void AS $$
DECLARE
  payment_record payments%ROWTYPE;
BEGIN
  -- Get payment record
  SELECT * INTO payment_record
  FROM payments p
  WHERE p.razorpay_payment_id = payment_id
  AND p.type = payment_type
  AND p.reference_id = reference_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment record not found';
  END IF;

  -- Update payment status
  UPDATE payments p
  SET 
    status = 'completed',
    completed_at = now()
  WHERE p.id = payment_record.id;

  -- Log payment completion
  INSERT INTO payment_logs (
    payment_id,
    event,
    status,
    data
  ) VALUES (
    payment_record.id,
    'payment_completed',
    'completed',
    jsonb_build_object(
      'payment_id', payment_id,
      'reference_id', reference_id,
      'type', payment_type
    )
  );

  -- Handle specific payment types
  CASE payment_type
    WHEN 'ad_campaign' THEN
      UPDATE ad_campaigns ac
      SET status = 'active'
      WHERE ac.id = reference_id;
      
    WHEN 'badge_subscription' THEN
      UPDATE badge_subscriptions bs
      SET payment_id = payment_record.id
      WHERE bs.id = reference_id;
  END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Payment Failure Handler
CREATE OR REPLACE FUNCTION handle_payment_failure_v3(payment_id uuid)
RETURNS void AS $$
DECLARE
  payment_record payments%ROWTYPE;
BEGIN
  -- Get payment record
  SELECT * INTO payment_record
  FROM payments p
  WHERE p.id = payment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment record not found';
  END IF;

  -- Update payment status
  UPDATE payments p
  SET status = 'failed'
  WHERE p.id = payment_id;

  -- Log payment failure
  INSERT INTO payment_logs (
    payment_id,
    event,
    status,
    data
  ) VALUES (
    payment_id,
    'payment_failed',
    'failed',
    jsonb_build_object(
      'payment_id', payment_record.razorpay_payment_id,
      'reference_id', payment_record.reference_id,
      'type', payment_record.type
    )
  );

  -- Handle specific payment types
  CASE payment_record.type
    WHEN 'ad_campaign' THEN
      -- Delete failed campaign
      DELETE FROM ad_campaigns ac
      WHERE ac.id = payment_record.reference_id;
      
    WHEN 'badge_subscription' THEN
      -- Delete failed subscription
      DELETE FROM badge_subscriptions bs
      WHERE bs.id = payment_record.reference_id;
  END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;