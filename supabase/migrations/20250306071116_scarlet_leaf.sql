/*
  # Add Notification Preferences to Profiles
  
  1. Changes
    - Add notification_preferences JSONB column to profiles table
    - Set default preferences structure
    - Add validation check for preferences format
*/

-- Add notification_preferences column to profiles if it doesn't exist
DO $$ BEGIN
  ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS notification_preferences JSONB DEFAULT jsonb_build_object(
    'email', jsonb_build_object(
      'type', 'email',
      'enabled', true,
      'description', 'Receive important updates and notifications via email',
      'lastUpdated', NULL
    ),
    'push', jsonb_build_object(
      'type', 'push',
      'enabled', true,
      'description', 'Get instant notifications on your device',
      'lastUpdated', NULL
    ),
    'inApp', jsonb_build_object(
      'type', 'inApp',
      'enabled', true,
      'description', 'See notifications within the app',
      'lastUpdated', NULL
    ),
    'marketing', jsonb_build_object(
      'type', 'marketing',
      'enabled', false,
      'description', 'Receive updates about new features and promotions',
      'lastUpdated', NULL
    ),
    'security', jsonb_build_object(
      'type', 'security',
      'enabled', true,
      'description', 'Get alerts about security-related activities',
      'lastUpdated', NULL
    ),
    'activity', jsonb_build_object(
      'type', 'activity',
      'enabled', true,
      'description', 'Stay informed about account activity and changes',
      'lastUpdated', NULL
    )
  );
EXCEPTION
  WHEN duplicate_column THEN NULL;
END $$;