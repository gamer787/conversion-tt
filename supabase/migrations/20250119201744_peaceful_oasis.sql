/*
  # Fix Avatar Storage Permissions

  1. Changes
    - Create avatars bucket with proper configuration
    - Set up simplified storage policies for avatars
    - Enable public read access
    - Allow authenticated users to manage their avatars
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
  DROP POLICY IF EXISTS "storage_select_policy" ON storage.objects;
  DROP POLICY IF EXISTS "storage_insert_policy" ON storage.objects;
  DROP POLICY IF EXISTS "storage_delete_policy" ON storage.objects;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create simplified storage policies
DO $$ 
BEGIN
  -- Public read access for all media
  CREATE POLICY "storage_select_policy" ON storage.objects
    FOR SELECT USING (bucket_id IN ('avatars', 'vibes', 'bangers'));

  -- Authenticated users can upload media
  CREATE POLICY "storage_insert_policy" ON storage.objects
    FOR INSERT WITH CHECK (
      bucket_id IN ('avatars', 'vibes', 'bangers')
      AND auth.role() = 'authenticated'
    );

  -- Users can delete their own media
  CREATE POLICY "storage_delete_policy" ON storage.objects
    FOR DELETE USING (
      bucket_id IN ('avatars', 'vibes', 'bangers')
      AND auth.role() = 'authenticated'
      AND auth.uid()::text = SPLIT_PART(name, '/', 1)
    );
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
END $$;

-- Enable RLS on storage.objects if not already enabled
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;