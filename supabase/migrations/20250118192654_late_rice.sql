/*
  # Fix mock profiles function

  1. Changes
    - Add proper error handling for mock profile creation
    - Add proper return type for the function
    - Add proper validation for input parameters
    - Add proper handling for username uniqueness
    - Add proper security context

  2. Security
    - Function runs with SECURITY DEFINER to ensure proper access
    - Search path is explicitly set to public
*/

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS create_mock_profile(uuid, text, text, account_type);

-- Create improved function with better error handling and return type
CREATE OR REPLACE FUNCTION create_mock_profile(
  mock_id uuid,
  mock_username text,
  mock_display_name text,
  mock_account_type account_type
)
RETURNS TABLE (
  success boolean,
  error text,
  profile json
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  created_profile profiles;
  base_username text;
  final_username text;
  counter integer := 0;
BEGIN
  -- Input validation
  IF mock_id IS NULL OR mock_username IS NULL OR mock_display_name IS NULL OR mock_account_type IS NULL THEN
    RETURN QUERY SELECT 
      false,
      'Invalid input parameters'::text,
      NULL::json;
    RETURN;
  END IF;

  -- Check if profile already exists
  SELECT * INTO created_profile FROM profiles WHERE id = mock_id;
  IF FOUND THEN
    RETURN QUERY SELECT 
      true,
      NULL::text,
      row_to_json(created_profile);
    RETURN;
  END IF;

  -- Generate unique username
  base_username := mock_username;
  final_username := base_username;
  
  WHILE EXISTS (SELECT 1 FROM profiles WHERE username = final_username) LOOP
    counter := counter + 1;
    final_username := base_username || '_' || counter;
  END LOOP;

  -- Create the mock profile
  INSERT INTO profiles (
    id,
    username,
    display_name,
    account_type,
    is_verified,
    created_at,
    updated_at
  ) VALUES (
    mock_id,
    final_username,
    mock_display_name,
    mock_account_type,
    false,
    now(),
    now()
  )
  RETURNING * INTO created_profile;

  RETURN QUERY SELECT 
    true,
    NULL::text,
    row_to_json(created_profile);
EXCEPTION
  WHEN OTHERS THEN
    RETURN QUERY SELECT 
      false,
      SQLERRM,
      NULL::json;
END;
$$;