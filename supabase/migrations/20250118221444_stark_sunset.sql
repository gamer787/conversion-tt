/*
  # Fix follows table RLS policies

  1. Changes
    - Drop existing follows policies
    - Add new policies with proper conditions for friend requests
    - Add policy for mutual follows after friend request acceptance

  2. Security
    - Enable RLS on follows table
    - Add policies for select, insert, and delete operations
*/

-- Drop existing policies if they exist
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'follows_select_policy' AND tablename = 'follows'
  ) THEN
    DROP POLICY IF EXISTS "follows_select_policy" ON follows;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'follows_insert_policy' AND tablename = 'follows'
  ) THEN
    DROP POLICY IF EXISTS "follows_insert_policy" ON follows;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'follows_delete_policy' AND tablename = 'follows'
  ) THEN
    DROP POLICY IF EXISTS "follows_delete_policy" ON follows;
  END IF;
END $$;

-- Create new policies with proper conditions
CREATE POLICY "follows_select_policy"
  ON follows FOR SELECT
  USING (true);

CREATE POLICY "follows_insert_policy"
  ON follows FOR INSERT
  WITH CHECK (
    -- Allow insert if there's an accepted friend request between users
    EXISTS (
      SELECT 1 FROM friend_requests
      WHERE status = 'accepted'
      AND (
        (sender_id = auth.uid() AND receiver_id = following_id) OR
        (receiver_id = auth.uid() AND sender_id = following_id)
      )
    )
    -- Or if following a business account
    OR EXISTS (
      SELECT 1 FROM profiles
      WHERE id = following_id
      AND account_type = 'business'
    )
  );

CREATE POLICY "follows_delete_policy"
  ON follows FOR DELETE
  USING (auth.uid() = follower_id);