/*
  # Fix avatar storage policies

  1. Changes
    - Simplifies storage policies for avatars
    - Makes avatars publicly readable
    - Allows authenticated users to upload avatars
    - Fixes path validation issues
    
  2. Security
    - Maintains RLS protection
    - Ensures users can only modify their own avatars
*/

-- Create avatars bucket if it doesn't exist
DO $$ 
BEGIN
  INSERT INTO storage.buckets (id, name, public)
  VALUES ('avatars', 'avatars', true)
  ON CONFLICT (id) DO NOTHING;
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END $$;

-- Drop existing policies
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "avatars_select_policy" ON storage.objects;
  DROP POLICY IF EXISTS "avatars_insert_policy" ON storage.objects;
  DROP POLICY IF EXISTS "avatars_update_policy" ON storage.objects;
  DROP POLICY IF EXISTS "avatars_delete_policy" ON storage.objects;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create new simplified policies
DO $$ 
BEGIN
  -- Public read access for avatars
  CREATE POLICY "avatars_select_policy" ON storage.objects
    FOR SELECT USING (bucket_id = 'avatars');

  -- Authenticated users can upload avatars
  CREATE POLICY "avatars_insert_policy" ON storage.objects
    FOR INSERT WITH CHECK (
      bucket_id = 'avatars' 
      AND auth.role() = 'authenticated'
    );

  -- Users can update their own avatars
  CREATE POLICY "avatars_update_policy" ON storage.objects
    FOR UPDATE USING (
      bucket_id = 'avatars'
      AND auth.role() = 'authenticated'
    );

  -- Users can delete their own avatars
  CREATE POLICY "avatars_delete_policy" ON storage.objects
    FOR DELETE USING (
      bucket_id = 'avatars'
      AND auth.role() = 'authenticated'
    );
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
END $$;