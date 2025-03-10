/*
  # Fix Messages Table and RLS Policies

  1. Changes
    - Drop and recreate messages table with proper structure
    - Add RLS policies for messages
    - Add functions for message permissions
    - Add indexes for better performance

  2. Security
    - Enable RLS
    - Add policies for select, insert, and update operations
    - Ensure proper access control based on friend requests and business follows
*/

-- Drop existing table if it exists
DROP TABLE IF EXISTS messages CASCADE;

-- Create messages table
CREATE TABLE messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id text NOT NULL,
  sender_id uuid NOT NULL REFERENCES profiles(id),
  receiver_id uuid NOT NULL REFERENCES profiles(id),
  content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  read_at timestamptz,
  CONSTRAINT valid_conversation_id CHECK (
    conversation_id = LEAST(sender_id::text, receiver_id::text) || '_' || GREATEST(sender_id::text, receiver_id::text)
  )
);

-- Enable RLS
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_receiver ON messages(sender_id, receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);
CREATE INDEX IF NOT EXISTS idx_messages_unread ON messages(receiver_id, read_at) WHERE read_at IS NULL;

-- Create RLS policies
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

-- Function to get unread message count
CREATE OR REPLACE FUNCTION get_unread_message_count(conversation_id text)
RETURNS bigint
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COUNT(*)
  FROM messages
  WHERE conversation_id = $1
  AND receiver_id = auth.uid()
  AND read_at IS NULL;
$$;