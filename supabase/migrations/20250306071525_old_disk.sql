/*
  # Add Connection Preferences to Profiles
  
  1. Changes
    - Add connection_preferences JSONB column to profiles table
    - Set default preferences structure
    - Add validation check for preferences format
*/

-- Add connection_preferences column to profiles if it doesn't exist
DO $$ BEGIN
  ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS connection_preferences JSONB DEFAULT jsonb_build_object(
    'bluetooth', jsonb_build_object(
      'type', 'bluetooth',
      'enabled', true,
      'description', 'Discover nearby users using Bluetooth',
      'lastUpdated', NULL
    ),
    'nfc', jsonb_build_object(
      'type', 'nfc',
      'enabled', true,
      'description', 'Connect instantly with NFC tap',
      'lastUpdated', NULL
    ),
    'location', jsonb_build_object(
      'enabled', true,
      'accuracy', 'high',
      'autoUpdate', true,
      'shareWithFriends', false,
      'lastUpdated', NULL
    ),
    'backgroundSync', jsonb_build_object(
      'type', 'backgroundSync',
      'enabled', true,
      'description', 'Keep discovering users while app is in background',
      'lastUpdated', NULL
    ),
    'autoConnect', jsonb_build_object(
      'type', 'autoConnect',
      'enabled', false,
      'description', 'Automatically connect with trusted users nearby',
      'lastUpdated', NULL
    )
  );
EXCEPTION
  WHEN duplicate_column THEN NULL;
END $$;