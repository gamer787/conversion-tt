-- Add RLS policies for posts table
CREATE POLICY "posts_select_policy"
  ON posts FOR SELECT
  USING (
    -- Users can view their own posts
    user_id = auth.uid()
    -- Or posts from users they have an accepted friend request with
    OR EXISTS (
      SELECT 1 FROM friend_requests
      WHERE status = 'accepted'
      AND (
        (sender_id = auth.uid() AND receiver_id = posts.user_id) OR
        (receiver_id = auth.uid() AND sender_id = posts.user_id)
      )
    )
    -- Or posts from business accounts they follow
    OR EXISTS (
      SELECT 1 FROM follows f
      JOIN profiles p ON p.id = posts.user_id
      WHERE f.follower_id = auth.uid()
      AND f.following_id = posts.user_id
      AND p.account_type = 'business'
    )
  );

CREATE POLICY "posts_insert_policy"
  ON posts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "posts_delete_policy"
  ON posts FOR DELETE
  USING (auth.uid() = user_id);

-- Add storage policies for content bucket
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