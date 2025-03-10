-- Drop existing objects if they exist
DROP TABLE IF EXISTS messages CASCADE;

-- Create messages table
CREATE TABLE messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id text NOT NULL,
  sender_id uuid REFERENCES profiles(id) NOT NULL,
  receiver_id uuid REFERENCES profiles(id) NOT NULL,
  content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  read_at timestamptz,
  -- Ensure conversation_id follows the format: smaller_uuid_larger_uuid
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
  WHERE conversation_id = conversation_id
  AND receiver_id = auth.uid()
  AND read_at IS NULL;
$$;

-- Function to get user's conversations with latest messages
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
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH user_conversations AS (
    -- Get all conversations where user is a participant
    SELECT DISTINCT m.conversation_id
    FROM messages m
    WHERE m.sender_id = user_id OR m.receiver_id = user_id
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
        AND m.receiver_id = user_id
        AND m.read_at IS NULL
      ) as unread_count,
      -- Extract other user's ID
      CASE 
        WHEN SPLIT_PART(uc.conversation_id, '_', 1)::uuid = user_id 
        THEN SPLIT_PART(uc.conversation_id, '_', 2)::uuid
        ELSE SPLIT_PART(uc.conversation_id, '_', 1)::uuid
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