/*
  # Payment System Validation Fix

  1. Changes
    - Drop and recreate payment validation constraints
    - Update NOT NULL constraints
    - Add new CHECK constraints with unique names
    - Enable RLS and add policies
    - Create payment validation trigger

  2. Security
    - Enable RLS on payments table
    - Add policies for payment access control
    - Validate payment amounts and types
*/

-- First check and drop existing constraints and triggers
DO $$ 
BEGIN
  -- Drop existing constraints if they exist
  EXECUTE (
    SELECT string_agg('ALTER TABLE payments DROP CONSTRAINT IF EXISTS ' || quote_ident(constraint_name) || ';', ' ')
    FROM information_schema.table_constraints
    WHERE table_name = 'payments' 
    AND constraint_type = 'CHECK'
  );

  -- Drop existing trigger if exists
  DROP TRIGGER IF EXISTS payment_validation_trigger ON payments;
END $$;

-- Set NOT NULL constraints and defaults
ALTER TABLE payments
  ALTER COLUMN user_id SET NOT NULL,
  ALTER COLUMN amount SET NOT NULL,
  ALTER COLUMN type SET NOT NULL,
  ALTER COLUMN currency SET NOT NULL,
  ALTER COLUMN status SET NOT NULL,
  ALTER COLUMN created_at SET DEFAULT now(),
  ALTER COLUMN status SET DEFAULT 'pending'::payment_status;

-- Add new CHECK constraints with unique names
DO $$ 
BEGIN
  -- Amount validation
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.check_constraints 
    WHERE constraint_name = 'payments_validate_amount_20250309'
  ) THEN
    ALTER TABLE payments
      ADD CONSTRAINT payments_validate_amount_20250309 CHECK (amount > 0);
  END IF;

  -- Payment type validation
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.check_constraints 
    WHERE constraint_name = 'payments_validate_type_20250309'
  ) THEN
    ALTER TABLE payments
      ADD CONSTRAINT payments_validate_type_20250309 CHECK (type IN ('ad_campaign', 'badge_subscription'));
  END IF;

  -- Currency validation
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.check_constraints 
    WHERE constraint_name = 'payments_validate_currency_20250309'
  ) THEN
    ALTER TABLE payments
      ADD CONSTRAINT payments_validate_currency_20250309 CHECK (currency = 'INR');
  END IF;
END $$;

-- Enable RLS
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Create or replace policies
DO $$ 
BEGIN
  -- Drop existing policies
  DROP POLICY IF EXISTS users_create_own_payments_policy ON payments;
  DROP POLICY IF EXISTS users_view_own_payments_policy ON payments;
  
  -- Create new policies
  CREATE POLICY users_create_own_payments_policy_20250309 ON payments
    FOR INSERT TO public
    WITH CHECK (auth.uid() = user_id);

  CREATE POLICY users_view_own_payments_policy_20250309 ON payments
    FOR SELECT TO public
    USING (auth.uid() = user_id);
END $$;

-- Create or replace payment validation function
CREATE OR REPLACE FUNCTION validate_payment()
RETURNS trigger AS $$
BEGIN
  -- Validate amount range based on type
  IF NEW.type = 'badge_subscription' THEN
    IF NOT (NEW.amount IN (99, 297)) THEN
      RAISE EXCEPTION 'Invalid badge subscription amount. Expected 99 or 297, got %', NEW.amount;
    END IF;
  ELSIF NEW.type = 'ad_campaign' THEN
    IF NEW.amount <= 0 THEN
      RAISE EXCEPTION 'Ad campaign amount must be greater than 0';
    END IF;
  END IF;

  -- Validate currency
  IF NEW.currency != 'INR' THEN
    RAISE EXCEPTION 'Only INR currency is supported';
  END IF;

  -- Validate metadata based on type
  IF NEW.type = 'badge_subscription' AND (
    NEW.metadata->>'category' IS NULL OR 
    NEW.metadata->>'role' IS NULL
  ) THEN
    RAISE EXCEPTION 'Badge subscription requires category and role in metadata';
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

-- Create payment validation trigger
CREATE TRIGGER payment_validation_trigger_20250309
  BEFORE INSERT OR UPDATE ON payments
  FOR EACH ROW
  EXECUTE FUNCTION validate_payment();