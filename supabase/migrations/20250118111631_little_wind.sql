/*
  # Fix profile creation policies

  1. Changes
    - Add policy to allow new users to insert their own profile
    - Update existing policies to be more specific about conditions
  
  2. Security
    - Maintains RLS on profiles table
    - Ensures users can only create their own profile
    - Preserves existing read/update policies
*/

-- Drop existing policies to recreate them with proper conditions
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;

-- Create new policies with proper conditions
CREATE POLICY "Public profiles are viewable by everyone"
  ON profiles FOR SELECT
  USING (true);

CREATE POLICY "Users can insert their own profile"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);