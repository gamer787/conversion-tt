-- Drop existing policies
DROP POLICY IF EXISTS "storage_select_policy" ON storage.objects;
DROP POLICY IF EXISTS "storage_insert_policy" ON storage.objects;
DROP POLICY IF EXISTS "storage_update_policy" ON storage.objects;
DROP POLICY IF EXISTS "storage_delete_policy" ON storage.objects;

-- Create avatars bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Create separate policies for different operations
CREATE POLICY "avatars_select_policy" ON storage.objects
FOR SELECT USING (
  bucket_id = 'avatars'
);

CREATE POLICY "avatars_insert_policy" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'avatars'
  AND auth.uid()::text = SPLIT_PART(name, '/', 1)
);

CREATE POLICY "avatars_update_policy" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'avatars'
  AND auth.uid()::text = SPLIT_PART(name, '/', 1)
);

CREATE POLICY "avatars_delete_policy" ON storage.objects
FOR DELETE USING (
  bucket_id = 'avatars'
  AND auth.uid()::text = SPLIT_PART(name, '/', 1)
);

-- Enable RLS on storage.objects if not already enabled
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;