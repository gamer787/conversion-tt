/*
  # Fix profile schema for business accounts

  1. Changes
    - Add industry and phone columns if they don't exist
    - Update RLS policies to handle business account fields
    - Add indexes for performance

  2. Security
    - Maintain existing RLS policies
    - Add specific policies for business fields
*/

-- Add industry and phone columns if they don't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'industry'
  ) THEN
    ALTER TABLE profiles ADD COLUMN industry text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'phone'
  ) THEN
    ALTER TABLE profiles ADD COLUMN phone text;
  END IF;
END $$;

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_profiles_account_type ON profiles(account_type);
CREATE INDEX IF NOT EXISTS idx_profiles_username_account_type ON profiles(username, account_type);

-- Update RLS policies to handle business fields
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id AND
    (
      -- For personal accounts, can't update business-specific fields
      (account_type = 'personal' AND (industry IS NULL AND phone IS NULL)) OR
      -- For business accounts, can update all fields
      account_type = 'business'
    )
  );