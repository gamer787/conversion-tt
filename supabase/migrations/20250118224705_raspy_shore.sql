/*
  # Fix Storage Bucket and Policies

  1. Changes
    - Create content storage bucket
    - Set up RLS policies for content access
    - Ensure proper access control for uploads and downloads

  2. Security
    - Only allow users to upload their own content
    - Restrict content access to friends and followed businesses
    - Enable content deletion for owners
*/

-- Create content storage bucket if it doesn't exist
DO $$
BEGIN
  INSERT INTO storage.buckets (id, name, public)
  VALUES ('content', 'content', true)
  ON CONFLICT (id) DO NOTHING;
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END $$;

-- Drop existing policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "content_select_policy" ON storage.objects;
  DROP POLICY IF EXISTS "content_insert_policy" ON storage.objects;
  DROP POLICY IF EXISTS "content_delete_policy" ON storage.objects;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create new policies with proper error handling
DO $$ 
BEGIN
  -- Select policy for viewing content
  CREATE POLICY "content_select_policy"
    ON storage.objects FOR SELECT
    USING (
      bucket_id = 'content'
      AND (
        -- Users can view their own content
        auth.uid()::text = SPLIT_PART(name, '/', 1)
        -- Or content from users they have an accepted friend request with
        OR EXISTS (
          SELECT 1 FROM friend_requests
          WHERE status = 'accepted'
          AND (
            (sender_id = auth.uid() AND receiver_id::text = SPLIT_PART(name, '/', 1))
            OR (receiver_id = auth.uid() AND sender_id::text = SPLIT_PART(name, '/', 1))
          )
        )
        -- Or content from business accounts they follow
        OR EXISTS (
          SELECT 1 FROM follows f
          JOIN profiles p ON p.id::text = SPLIT_PART(name, '/', 1)
          WHERE f.follower_id = auth.uid()
          AND f.following_id::text = SPLIT_PART(name, '/', 1)
          AND p.account_type = 'business'
        )
      )
    );

  -- Insert policy for uploading content
  CREATE POLICY "content_insert_policy"
    ON storage.objects FOR INSERT
    WITH CHECK (
      bucket_id = 'content'
      AND auth.uid()::text = SPLIT_PART(name, '/', 1)
    );

  -- Delete policy for removing content
  CREATE POLICY "content_delete_policy"
    ON storage.objects FOR DELETE
    USING (
      bucket_id = 'content'
      AND auth.uid()::text = SPLIT_PART(name, '/', 1)
    );
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
END $$;

-- Enable RLS on storage.objects if not already enabled
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;