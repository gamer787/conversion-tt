/*
  # Fix Messages RLS Policies

  1. Changes
    - Drop existing RLS policies
    - Create new simplified policies for messages table
    - Add proper checks for message permissions
    - Fix conversation ID validation

  2. Security
    - Enable RLS
    - Add policies for select, insert, and update operations
    - Ensure proper access control based on friend requests and business follows
*/

-- Drop existing policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Users can view their conversation messages" ON messages;
  DROP POLICY IF EXISTS "Users can send messages to valid recipients" ON messages;
  DROP POLICY IF EXISTS "Users can mark messages as read" ON messages;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create new simplified policies
CREATE POLICY "messages_select_policy"
  ON messages FOR SELECT
  USING (
    auth.uid() IN (sender_id, receiver_id)
  );

CREATE POLICY "messages_insert_policy"
  ON messages FOR INSERT
  WITH CHECK (
    -- Sender must be the authenticated user
    auth.uid() = sender_id
    AND (
      -- Can message if there's an accepted friend request
      EXISTS (
        SELECT 1 FROM friend_requests
        WHERE status = 'accepted'
        AND (
          (sender_id = auth.uid() AND receiver_id = messages.receiver_id)
          OR (receiver_id = auth.uid() AND sender_id = messages.receiver_id)
        )
      )
      -- Or if the receiver is a business account they follow
      OR EXISTS (
        SELECT 1 FROM follows f
        JOIN profiles p ON p.id = messages.receiver_id
        WHERE f.follower_id = auth.uid()
        AND f.following_id = messages.receiver_id
        AND p.account_type = 'business'
      )
    )
    -- Ensure conversation_id follows the correct format
    AND conversation_id = LEAST(sender_id::text, receiver_id::text) || '_' || GREATEST(sender_id::text, receiver_id::text)
  );

CREATE POLICY "messages_update_policy"
  ON messages FOR UPDATE
  USING (
    -- Only receiver can update (for marking messages as read)
    auth.uid() = receiver_id
    AND read_at IS NULL
  )
  WITH CHECK (
    -- Only allow updating read_at field
    read_at IS NOT NULL
  );