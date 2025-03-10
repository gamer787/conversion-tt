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
DECLARE
  created_profile profiles;
BEGIN
  -- Validate input
  IF mock_id IS NULL OR mock_username IS NULL OR mock_display_name IS NULL OR mock_account_type IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Invalid input parameters');
  END IF;

  -- Check if profile already exists
  SELECT * INTO created_profile FROM profiles WHERE id = mock_id;
  IF FOUND THEN
    RETURN json_build_object(
      'success', true,
      'message', 'Profile already exists',
      'profile', row_to_json(created_profile)
    );
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
  )
  RETURNING * INTO created_profile;

  RETURN json_build_object(
    'success', true,
    'profile', row_to_json(created_profile)
  );
EXCEPTION
  WHEN unique_violation THEN
    -- Handle username uniqueness violation by appending a random suffix
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
      mock_username || '_' || floor(random() * 1000)::text,
      mock_display_name,
      mock_account_type,
      false,
      now(),
      now()
    )
    RETURNING * INTO created_profile;

    RETURN json_build_object(
      'success', true,
      'profile', row_to_json(created_profile)
    );
  WHEN OTHERS THEN
    -- Handle other errors
    RETURN json_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$;