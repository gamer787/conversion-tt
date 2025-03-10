/*
  # Add mock profile creation function

  1. New Functions
    - `create_mock_profile`: Creates mock profiles for discovered users with proper security context
  
  2. Security
    - Function runs with security definer to bypass RLS
    - Validates input data before creation
*/

-- Function to create mock profiles with proper security context
CREATE OR REPLACE FUNCTION create_mock_profile(
  mock_id uuid,
  mock_username text,
  mock_display_name text,
  mock_account_type account_type
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Validate input
  IF mock_id IS NULL OR mock_username IS NULL OR mock_display_name IS NULL OR mock_account_type IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Invalid input parameters');
  END IF;

  -- Check if profile already exists
  IF EXISTS (SELECT 1 FROM profiles WHERE id = mock_id) THEN
    RETURN json_build_object('success', true, 'message', 'Profile already exists');
  END IF;

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
    mock_username,
    mock_display_name,
    mock_account_type,
    false,
    now(),
    now()
  );

  RETURN json_build_object('success', true);
EXCEPTION
  WHEN unique_violation THEN
    -- Handle username uniqueness violation
    RETURN json_build_object(
      'success', false,
      'error', 'Username already taken'
    );
  WHEN OTHERS THEN
    -- Handle other errors
    RETURN json_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$;