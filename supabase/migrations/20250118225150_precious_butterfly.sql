/*
  # Fix Storage Upload Policy

  1. Changes
    - Simplify storage policies
    - Fix upload permissions
    - Ensure proper bucket access

  2. Security
    - Maintain proper access control
    - Enable uploads for authenticated users
    - Restrict content access appropriately
*/

-- Drop existing policies
DROP POLICY IF EXISTS "storage_policy" ON storage.objects;

-- Create separate policies for different operations
CREATE POLICY "storage_select_policy" ON storage.objects
FOR SELECT USING (
  CASE bucket_id
    WHEN 'avatars' THEN true  -- Avatars are public
    WHEN 'vibes' THEN true    -- Vibes are public
    WHEN 'bangers' THEN true  -- Bangers are public
    ELSE false
  END
);

CREATE POLICY "storage_insert_policy" ON storage.objects
FOR INSERT WITH CHECK (
  CASE bucket_id
    WHEN 'avatars' THEN auth.uid()::text = SPLIT_PART(name, '/', 1)
    WHEN 'vibes' THEN auth.uid()::text = SPLIT_PART(name, '/', 1)
    WHEN 'bangers' THEN auth.uid()::text = SPLIT_PART(name, '/', 1)
    ELSE false
  END
);

CREATE POLICY "storage_update_policy" ON storage.objects
FOR UPDATE USING (
  CASE bucket_id
    WHEN 'avatars' THEN auth.uid()::text = SPLIT_PART(name, '/', 1)
    WHEN 'vibes' THEN auth.uid()::text = SPLIT_PART(name, '/', 1)
    WHEN 'bangers' THEN auth.uid()::text = SPLIT_PART(name, '/', 1)
    ELSE false
  END
);

CREATE POLICY "storage_delete_policy" ON storage.objects
FOR DELETE USING (
  CASE bucket_id
    WHEN 'avatars' THEN auth.uid()::text = SPLIT_PART(name, '/', 1)
    WHEN 'vibes' THEN auth.uid()::text = SPLIT_PART(name, '/', 1)
    WHEN 'bangers' THEN auth.uid()::text = SPLIT_PART(name, '/', 1)
    ELSE false
  END
);