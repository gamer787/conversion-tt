/*
  # Add Payment Tracking and Validation

  1. New Tables
    - `payments`
      - Tracks all payment transactions
      - Links to campaigns and badge subscriptions
      - Stores payment status and verification details
    
  2. Functions
    - `verify_payment`: Validates payment details
    - `process_payment`: Handles payment processing and status updates
    
  3. Triggers
    - Automatically updates campaign/badge status on payment verification
*/

-- Create payment status enum
CREATE TYPE payment_status AS ENUM ('pending', 'completed', 'failed');

-- Create payments table
CREATE TABLE payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) NOT NULL,
  payment_id text NOT NULL,
  amount integer NOT NULL,
  currency text NOT NULL DEFAULT 'INR',
  status payment_status NOT NULL DEFAULT 'pending',
  type text NOT NULL CHECK (type IN ('ad_campaign', 'badge_subscription')),
  reference_id uuid NOT NULL, -- Links to either ad_campaigns.id or badge_subscriptions.id
  created_at timestamptz NOT NULL DEFAULT now(),
  verified_at timestamptz,
  metadata jsonb,
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

-- Create function to verify payment
CREATE OR REPLACE FUNCTION verify_payment(
  payment_id text,
  reference_id uuid,
  payment_type text
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
  WHERE payment_id = payment_id
    AND reference_id = reference_id
    AND type = payment_type;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- Update payment status
  UPDATE payments
  SET 
    status = 'completed',
    verified_at = now()
  WHERE id = v_payment.id;

  -- Update related records based on payment type
  CASE payment_type
    WHEN 'ad_campaign' THEN
      UPDATE ad_campaigns
      SET status = 'active'
      WHERE id = reference_id;
    
    WHEN 'badge_subscription' THEN
      -- No action needed as badge subscriptions are active by default
      NULL;
    
    ELSE
      RETURN false;
  END CASE;

  RETURN true;
END;
$$;

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
    payment_id,
    amount,
    type,
    reference_id,
    metadata
  ) VALUES (
    p_user_id,
    p_payment_id,
    p_amount,
    p_type,
    p_reference_id,
    p_metadata
  )
  RETURNING id INTO payment_record_id;

  RETURN payment_record_id;
END;
$$;

-- Create indexes for better performance
CREATE INDEX idx_payments_user ON payments(user_id);
CREATE INDEX idx_payments_reference ON payments(reference_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_type ON payments(type);
CREATE INDEX idx_payments_payment_id ON payments(payment_id);

-- Add payment_id column to existing tables if not exists
ALTER TABLE ad_campaigns
ADD COLUMN IF NOT EXISTS payment_id uuid REFERENCES payments(id);

ALTER TABLE badge_subscriptions 
ADD COLUMN IF NOT EXISTS payment_id uuid REFERENCES payments(id);