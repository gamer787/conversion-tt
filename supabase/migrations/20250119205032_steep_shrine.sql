/*
  # Messages Schema

  1. New Tables
    - `messages`
      - `id` (uuid, primary key)
      - `conversation_id` (text, composite key from user IDs)
      - `sender_id` (uuid, references profiles)
      - `content` (text)
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS on messages table
    - Add policies for:
      - Selecting messages (only for conversation participants)
      - Inserting messages (only for conversation participants)
      - Deleting messages (only for sender)
*/

-- Create messages table
CREATE TABLE IF NOT EXISTS messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id text NOT NULL,
  sender_id uuid REFERENCES profiles(id) NOT NULL,
  content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Create indexes for better performance
CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX idx_messages_sender_id ON messages(sender_id);
CREATE INDEX idx_messages_created_at ON messages(created_at);

-- Create function to check if user is conversation participant
CREATE OR REPLACE FUNCTION is_conversation_participant(conversation_id text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Extract user IDs from conversation_id (format: smaller_uuid_larger_uuid)
  DECLARE
    user1_id uuid := (SELECT uuid(split_part(conversation_id, '_', 1)));
    user2_id uuid := (SELECT uuid(split_part(conversation_id, '_', 2)));
  BEGIN
    -- Check if current user is one of the participants
    RETURN auth.uid() IN (user1_id, user2_id);
  END;
END;
$$;

-- Create policies
CREATE POLICY "Users can view their conversation messages"
  ON messages FOR SELECT
  USING (is_conversation_participant(conversation_id));

CREATE POLICY "Users can send messages in their conversations"
  ON messages FOR INSERT
  WITH CHECK (
    is_conversation_participant(conversation_id)
    AND auth.uid() = sender_id
  );

CREATE POLICY "Users can delete their own messages"
  ON messages FOR DELETE
  USING (auth.uid() = sender_id);

-- Create function to get user's conversations
CREATE OR REPLACE FUNCTION get_user_conversations(user_id uuid)
RETURNS TABLE (
  conversation_id text,
  other_user_id uuid,
  last_message text,
  last_message_at timestamptz,
  unread_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH user_conversations AS (
    -- Get all conversations where user is a participant
    SELECT DISTINCT m.conversation_id
    FROM messages m
    WHERE is_conversation_participant(m.conversation_id)
  ),
  conversation_details AS (
    -- Get latest message and unread count for each conversation
    SELECT 
      uc.conversation_id,
      (
        SELECT m.content
        FROM messages m
        WHERE m.conversation_id = uc.conversation_id
        ORDER BY m.created_at DESC
        LIMIT 1
      ) as last_message,
      (
        SELECT m.created_at
        FROM messages m
        WHERE m.conversation_id = uc.conversation_id
        ORDER BY m.created_at DESC
        LIMIT 1
      ) as last_message_at,
      (
        SELECT COUNT(*)
        FROM messages m
        WHERE m.conversation_id = uc.conversation_id
        AND m.sender_id != user_id
        -- Add read receipts later if needed
      ) as unread_count,
      -- Extract other user's ID
      CASE 
        WHEN split_part(uc.conversation_id, '_', 1)::uuid = user_id 
        THEN split_part(uc.conversation_id, '_', 2)::uuid
        ELSE split_part(uc.conversation_id, '_', 1)::uuid
      END as other_user_id
    FROM user_conversations uc
  )
  SELECT 
    cd.conversation_id,
    cd.other_user_id,
    cd.last_message,
    cd.last_message_at,
    cd.unread_count
  FROM conversation_details cd
  ORDER BY cd.last_message_at DESC NULLS LAST;
END;
$$;