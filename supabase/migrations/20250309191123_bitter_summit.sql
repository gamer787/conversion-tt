/*
  # Payment System Constraints

  1. Changes
    - Adds NOT NULL constraints to required payment columns
    - Adds CHECK constraints for payment validation
    - Enables RLS and adds security policies
    - Creates payment validation trigger

  2. Security
    - Enables RLS on payments table
    - Adds policies for users to manage their own payments
    - Validates payment amounts and types

  3. Validation
    - Ensures payment amounts are positive
    - Validates payment types and currency
    - Enforces badge subscription pricing
*/

-- First check if constraints already exist and drop them if needed
DO $$ 
BEGIN
  -- Drop existing constraints if they exist
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'payment_amount_check' AND table_name = 'payments') THEN
    ALTER TABLE payments DROP CONSTRAINT payment_amount_check;
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'payment_type_check' AND table_name = 'payments') THEN
    ALTER TABLE payments DROP CONSTRAINT payment_type_check;
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'payment_currency_check' AND table_name = 'payments') THEN
    ALTER TABLE payments DROP CONSTRAINT payment_currency_check;
  END IF;
END $$;

-- Add NOT NULL constraints if not already present
DO $$ 
BEGIN
  -- Check each column and add NOT NULL if needed
  IF EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'payments' 
    AND column_name = 'user_id' 
    AND is_nullable = 'YES'
  ) THEN
    ALTER TABLE payments ALTER COLUMN user_id SET NOT NULL;
  END IF;

  IF EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'payments' 
    AND column_name = 'amount' 
    AND is_nullable = 'YES'
  ) THEN
    ALTER TABLE payments ALTER COLUMN amount SET NOT NULL;
  END IF;

  IF EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'payments' 
    AND column_name = 'type' 
    AND is_nullable = 'YES'
  ) THEN
    ALTER TABLE payments ALTER COLUMN type SET NOT NULL;
  END IF;

  IF EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'payments' 
    AND column_name = 'currency' 
    AND is_nullable = 'YES'
  ) THEN
    ALTER TABLE payments ALTER COLUMN currency SET NOT NULL;
  END IF;

  IF EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'payments' 
    AND column_name = 'status' 
    AND is_nullable = 'YES'
  ) THEN
    ALTER TABLE payments ALTER COLUMN status SET NOT NULL;
  END IF;
END $$;

-- Set default values
ALTER TABLE payments 
  ALTER COLUMN created_at SET DEFAULT now(),
  ALTER COLUMN status SET DEFAULT 'pending'::payment_status;

-- Add CHECK constraints with new unique names
ALTER TABLE payments
  ADD CONSTRAINT payments_amount_positive CHECK (amount > 0),
  ADD CONSTRAINT payments_valid_type CHECK (type IN ('ad_campaign', 'badge_subscription')),
  ADD CONSTRAINT payments_valid_currency CHECK (currency = 'INR');

-- Enable RLS if not already enabled
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Add policies if they don't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'payments' 
    AND policyname = 'users_create_own_payments_new'
  ) THEN
    CREATE POLICY "users_create_own_payments_new" ON payments
      FOR INSERT TO public
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'payments' 
    AND policyname = 'users_view_own_payments_new'
  ) THEN
    CREATE POLICY "users_view_own_payments_new" ON payments
      FOR SELECT TO public
      USING (auth.uid() = user_id);
  END IF;
END $$;

-- Create or replace payment validation function
CREATE OR REPLACE FUNCTION validate_payment()
RETURNS trigger AS $$
BEGIN
  -- Validate amount range based on type
  IF NEW.type = 'badge_subscription' THEN
    IF NOT (NEW.amount IN (99, 297)) THEN
      RAISE EXCEPTION 'Invalid badge subscription amount';
    END IF;
  END IF;

  -- Validate currency
  IF NEW.currency != 'INR' THEN
    RAISE EXCEPTION 'Only INR currency is supported';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop and recreate trigger
DROP TRIGGER IF EXISTS payment_validation_trigger ON payments;
CREATE TRIGGER payment_validation_trigger
  BEFORE INSERT ON payments
  FOR EACH ROW
  EXECUTE FUNCTION validate_payment();