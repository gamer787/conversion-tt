/*
  # Add interactions table and policies

  1. Changes
    - Create interactions table for likes and comments
    - Add policies for interactions
    - Create partial unique index for likes

  2. Security
    - Enable RLS for interactions table
    - Ensure users can only interact with posts they can view
    - Allow users to delete their own interactions
*/

-- Create interactions table if it doesn't exist
CREATE TABLE IF NOT EXISTS interactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) NOT NULL,
  post_id uuid REFERENCES posts(id) NOT NULL,
  type text NOT NULL CHECK (type IN ('like', 'comment')),
  comment_text text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Create partial unique index for likes
CREATE UNIQUE INDEX idx_unique_likes 
ON interactions (user_id, post_id) 
WHERE type = 'like';

-- Enable RLS
ALTER TABLE interactions ENABLE ROW LEVEL SECURITY;

-- Create policies for interactions
CREATE POLICY "interactions_select_policy"
  ON interactions FOR SELECT
  USING (
    -- Users can view interactions on posts they can see
    EXISTS (
      SELECT 1 FROM posts
      WHERE id = interactions.post_id
      AND (
        -- Own posts
        user_id = auth.uid()
        -- Or posts from friends
        OR EXISTS (
          SELECT 1 FROM friend_requests
          WHERE status = 'accepted'
          AND (
            (sender_id = auth.uid() AND receiver_id = posts.user_id) OR
            (receiver_id = auth.uid() AND sender_id = posts.user_id)
          )
        )
        -- Or posts from followed businesses
        OR EXISTS (
          SELECT 1 FROM follows f
          JOIN profiles p ON p.id = posts.user_id
          WHERE f.follower_id = auth.uid()
          AND f.following_id = posts.user_id
          AND p.account_type = 'business'
        )
      )
    )
  );

CREATE POLICY "interactions_insert_policy"
  ON interactions FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM posts
      WHERE id = post_id
      AND (
        -- Can interact with own posts
        user_id = auth.uid()
        -- Or posts from friends
        OR EXISTS (
          SELECT 1 FROM friend_requests
          WHERE status = 'accepted'
          AND (
            (sender_id = auth.uid() AND receiver_id = posts.user_id) OR
            (receiver_id = auth.uid() AND sender_id = posts.user_id)
          )
        )
        -- Or posts from followed businesses
        OR EXISTS (
          SELECT 1 FROM follows f
          JOIN profiles p ON p.id = posts.user_id
          WHERE f.follower_id = auth.uid()
          AND f.following_id = posts.user_id
          AND p.account_type = 'business'
        )
      )
    )
  );

CREATE POLICY "interactions_delete_policy"
  ON interactions FOR DELETE
  USING (auth.uid() = user_id);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_interactions_post_id ON interactions(post_id);
CREATE INDEX IF NOT EXISTS idx_interactions_user_post ON interactions(user_id, post_id);
CREATE INDEX IF NOT EXISTS idx_interactions_type ON interactions(type);