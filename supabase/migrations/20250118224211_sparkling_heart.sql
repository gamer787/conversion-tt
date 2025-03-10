/*
  # Create content bucket and update storage policies

  1. Changes
    - Create content storage bucket if it doesn't exist
    - Drop existing policies if they exist
    - Create new policies for content access control

  2. Security
    - Enable RLS for content bucket
    - Add policies to ensure users can only:
      - View their own content
      - View content from accepted friends
      - View content from followed business accounts
*/

-- Create content storage bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('content', 'content', true)
ON CONFLICT (id) DO NOTHING;

-- Drop existing policies if they exist
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE policyname = 'content_select_policy' 
    AND tablename = 'objects' 
    AND schemaname = 'storage'
  ) THEN
    DROP POLICY IF EXISTS "content_select_policy" ON storage.objects;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE policyname = 'content_insert_policy' 
    AND tablename = 'objects' 
    AND schemaname = 'storage'
  ) THEN
    DROP POLICY IF EXISTS "content_insert_policy" ON storage.objects;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE policyname = 'content_delete_policy' 
    AND tablename = 'objects' 
    AND schemaname = 'storage'
  ) THEN
    DROP POLICY IF EXISTS "content_delete_policy" ON storage.objects;
  END IF;
END $$;

-- Create new policies
CREATE POLICY "content_select_policy"
  ON storage.objects FOR SELECT
  USING (
    -- Users can view their own content
    (bucket_id = 'content' AND auth.uid()::text = SPLIT_PART(name, '/', 1))
    -- Or content from users they have an accepted friend request with
    OR EXISTS (
      SELECT 1 FROM friend_requests
      WHERE status = 'accepted'
      AND (
        (sender_id = auth.uid() AND receiver_id::text = SPLIT_PART(name, '/', 1)) OR
        (receiver_id = auth.uid() AND sender_id::text = SPLIT_PART(name, '/', 1))
      )
    )
    -- Or content from business accounts they follow
    OR EXISTS (
      SELECT 1 FROM follows f
      JOIN profiles p ON p.id = auth.uid()
      WHERE f.follower_id = auth.uid()
      AND f.following_id::text = SPLIT_PART(name, '/', 1)
      AND p.account_type = 'business'
    )
  );

CREATE POLICY "content_insert_policy"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'content'
    AND auth.uid()::text = SPLIT_PART(name, '/', 1)
  );

CREATE POLICY "content_delete_policy"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'content'
    AND auth.uid()::text = SPLIT_PART(name, '/', 1)
  );