/*
  # Messages System Setup

  1. New Tables
    - `messages`
      - `id` (uuid, primary key)
      - `conversation_id` (text)
      - `sender_id` (uuid, references profiles)
      - `receiver_id` (uuid, references profiles)
      - `content` (text)
      - `created_at` (timestamptz)
      - `read_at` (timestamptz, nullable)

  2. Functions
    - `can_access_conversation`: Checks if a user can access a conversation
    - `can_message_user`: Checks if a user can message another user
    - `get_unread_message_count`: Gets unread message count for a conversation

  3. Policies
    - Select: Users can view their conversation messages
    - Insert: Users can send messages to valid recipients
    - Update: Users can mark their received messages as read
*/

-- Drop existing objects if they exist
DROP TABLE IF EXISTS messages CASCADE;
DROP FUNCTION IF EXISTS can_access_conversation CASCADE;
DROP FUNCTION IF EXISTS can_message_user CASCADE;
DROP FUNCTION IF EXISTS get_unread_message_count CASCADE;

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
CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX idx_messages_sender_receiver ON messages(sender_id, receiver_id);
CREATE INDEX idx_messages_created_at ON messages(created_at);
CREATE INDEX idx_messages_unread ON messages(receiver_id, read_at) WHERE read_at IS NULL;

-- Function to check if user can access a conversation
CREATE FUNCTION can_access_conversation(conversation_id text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user1_id uuid;
  user2_id uuid;
BEGIN
  -- Extract user IDs from conversation_id
  user1_id := (SELECT uuid(split_part(conversation_id, '_', 1)));
  user2_id := (SELECT uuid(split_part(conversation_id, '_', 2)));
  
  -- Check if current user is one of the participants
  RETURN auth.uid() IN (user1_id, user2_id);
END;
$$;

-- Function to check if users can message each other
CREATE FUNCTION can_message_user(target_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Users can message if:
  -- 1. They have an accepted friend request between them
  -- 2. The target is a business account they follow
  RETURN EXISTS (
    -- Check for accepted friend request
    SELECT 1 FROM friend_requests
    WHERE status = 'accepted'
    AND (
      (sender_id = auth.uid() AND receiver_id = target_user_id)
      OR (receiver_id = auth.uid() AND sender_id = target_user_id)
    )
  ) OR EXISTS (
    -- Check if target is a followed business
    SELECT 1 FROM follows f
    JOIN profiles p ON p.id = target_user_id
    WHERE f.follower_id = auth.uid()
    AND f.following_id = target_user_id
    AND p.account_type = 'business'
  );
END;
$$;

-- Function to get unread message count
CREATE FUNCTION get_unread_message_count(conversation_id text)
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

-- RLS Policies
CREATE POLICY "Users can view their conversation messages"
  ON messages FOR SELECT
  USING (can_access_conversation(conversation_id));

CREATE POLICY "Users can send messages to valid recipients"
  ON messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id
    AND can_message_user(receiver_id)
    AND conversation_id = LEAST(sender_id::text, receiver_id::text) || '_' || GREATEST(sender_id::text, receiver_id::text)
  );

CREATE POLICY "Users can mark messages as read"
  ON messages FOR UPDATE
  USING (
    auth.uid() = receiver_id
    AND read_at IS NULL
  )
  WITH CHECK (
    read_at IS NOT NULL
  );