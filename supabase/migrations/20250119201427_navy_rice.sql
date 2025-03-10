-- Create storage buckets if they don't exist
DO $$ 
BEGIN
  INSERT INTO storage.buckets (id, name, public)
  VALUES 
    ('avatars', 'avatars', true),
    ('vibes', 'vibes', true),
    ('bangers', 'bangers', true)
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
  DROP POLICY IF EXISTS "vibes_select_policy" ON storage.objects;
  DROP POLICY IF EXISTS "vibes_insert_policy" ON storage.objects;
  DROP POLICY IF EXISTS "vibes_delete_policy" ON storage.objects;
  DROP POLICY IF EXISTS "bangers_select_policy" ON storage.objects;
  DROP POLICY IF EXISTS "bangers_insert_policy" ON storage.objects;
  DROP POLICY IF EXISTS "bangers_delete_policy" ON storage.objects;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create unified storage policies
DO $$ 
BEGIN
  -- Public read access for all media
  CREATE POLICY "media_select_policy" ON storage.objects
    FOR SELECT USING (
      bucket_id IN ('avatars', 'vibes', 'bangers')
    );

  -- Authenticated users can upload media
  CREATE POLICY "media_insert_policy" ON storage.objects
    FOR INSERT WITH CHECK (
      bucket_id IN ('avatars', 'vibes', 'bangers')
      AND auth.role() = 'authenticated'
    );

  -- Users can delete their own media
  CREATE POLICY "media_delete_policy" ON storage.objects
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