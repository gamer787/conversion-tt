/*
  # Add industry field for business profiles

  1. Changes
    - Add industry column to profiles table for business accounts
    - Add industry to profile RLS policies
*/

-- Add industry column if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'industry'
  ) THEN
    ALTER TABLE profiles ADD COLUMN industry text;
  END IF;
END $$;