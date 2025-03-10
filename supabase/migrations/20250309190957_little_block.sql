/*
  # Fix payment validation and constraints

  1. Changes
    - Add missing NOT NULL constraints
    - Add payment type validation
    - Add currency validation
    - Add amount validation for badge subscriptions
    - Add payment validation trigger

  2. Security
    - Add RLS policies for payment management
*/

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS validate_payment_trigger ON payments;
DROP FUNCTION IF EXISTS validate_payment();

-- Add NOT NULL constraints if not already present
DO $$ 
BEGIN
  -- Add NOT NULL constraints only if they don't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'payments' 
    AND column_name = 'user_id' 
    AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE payments ALTER COLUMN user_id SET NOT NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'payments' 
    AND column_name = 'amount' 
    AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE payments ALTER COLUMN amount SET NOT NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'payments' 
    AND column_name = 'type' 
    AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE payments ALTER COLUMN type SET NOT NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'payments' 
    AND column_name = 'currency' 
    AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE payments ALTER COLUMN currency SET NOT NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'payments' 
    AND column_name = 'status' 
    AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE payments ALTER COLUMN status SET NOT NULL;
  END IF;
END $$;

-- Set default values
ALTER TABLE payments 
  ALTER COLUMN created_at SET DEFAULT now(),
  ALTER COLUMN status SET DEFAULT 'pending'::payment_status;

-- Drop existing constraints if they exist
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'valid_amount') THEN
    ALTER TABLE payments DROP CONSTRAINT valid_amount;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'valid_payment_type') THEN
    ALTER TABLE payments DROP CONSTRAINT valid_payment_type;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'valid_currency') THEN
    ALTER TABLE payments DROP CONSTRAINT valid_currency;
  END IF;
END $$;

-- Add constraints with new names to avoid conflicts
ALTER TABLE payments
  ADD CONSTRAINT payment_amount_check CHECK (amount > 0),
  ADD CONSTRAINT payment_type_check CHECK (type IN ('ad_campaign', 'badge_subscription')),
  ADD CONSTRAINT payment_currency_check CHECK (currency = 'INR');

-- Enable RLS if not already enabled
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS users_create_own_payments ON payments;
DROP POLICY IF EXISTS users_view_own_payments ON payments;

-- Create new policies
CREATE POLICY "users_create_own_payments_policy" ON payments
  FOR INSERT TO public
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_view_own_payments_policy" ON payments
  FOR SELECT TO public
  USING (auth.uid() = user_id);

-- Create payment validation function
CREATE OR REPLACE FUNCTION validate_payment()
RETURNS trigger AS $$
BEGIN
  -- Validate amount range based on type
  IF NEW.type = 'badge_subscription' THEN
    IF NOT (NEW.amount IN (99, 297)) THEN
      RAISE EXCEPTION 'Invalid badge subscription amount. Expected ₹99 or ₹297.';
    END IF;
  END IF;

  -- Validate currency
  IF NEW.currency != 'INR' THEN
    RAISE EXCEPTION 'Only INR currency is supported.';
  END IF;

  -- Set default status if not provided
  IF NEW.status IS NULL THEN
    NEW.status := 'pending'::payment_status;
  END IF;

  -- Set created_at if not provided
  IF NEW.created_at IS NULL THEN
    NEW.created_at := now();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for payment validation
CREATE TRIGGER payment_validation_trigger
  BEFORE INSERT ON payments
  FOR EACH ROW
  EXECUTE FUNCTION validate_payment();