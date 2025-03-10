/*
  # Fix profile creation and policies

  1. Changes
    - Add trigger to automatically create profile when user signs up
    - Update RLS policies to allow profile creation and updates
    - Add function to handle profile creation

  2. Security
    - Enable RLS
    - Add policies for profile management
*/

-- Create a function to handle profile creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, username, display_name, account_type)
  VALUES (
    new.id,
    LOWER(SPLIT_PART(new.email, '@', 1)), -- Default username from email
    SPLIT_PART(new.email, '@', 1), -- Default display name from email
    'personal' -- Default account type
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a trigger to automatically create profile
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Update policies to ensure proper access
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- Add index for username lookups
CREATE INDEX IF NOT EXISTS profiles_username_idx ON profiles (username);