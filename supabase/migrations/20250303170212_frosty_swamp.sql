-- Drop existing message policies
DROP POLICY IF EXISTS "messages_select_policy" ON messages;
DROP POLICY IF EXISTS "messages_insert_policy" ON messages;
DROP POLICY IF EXISTS "messages_update_policy" ON messages;
DROP POLICY IF EXISTS "messages_delete_policy" ON messages;

-- Create message type enum if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'message_type') THEN
    CREATE TYPE message_type AS ENUM (
      'text',
      'image',
      'video',
      'voice',
      'gif',
      'sticker'
    );
  END IF;
END $$;

-- Create message status enum if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'message_status') THEN
    CREATE TYPE message_status AS ENUM (
      'sent',
      'delivered',
      'seen'
    );
  END IF;
END $$;

-- Create conversations table if it doesn't exist
CREATE TABLE IF NOT EXISTS conversations (
  id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  title text,
  is_group boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  last_message_at timestamptz,
  encryption_key text
);

-- Create conversation participants table if it doesn't exist
CREATE TABLE IF NOT EXISTS conversation_participants (
  conversation_id text REFERENCES conversations(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(),
  last_read_at timestamptz,
  is_admin boolean NOT NULL DEFAULT false,
  PRIMARY KEY (conversation_id, user_id)
);

-- Create messages table if it doesn't exist
CREATE TABLE IF NOT EXISTS messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id text REFERENCES conversations(id) ON DELETE CASCADE NOT NULL,
  sender_id uuid REFERENCES profiles(id) ON DELETE SET NULL NOT NULL,
  receiver_id uuid REFERENCES profiles(id),
  message_type message_type NOT NULL DEFAULT 'text',
  content text,
  media_url text,
  reply_to_id uuid REFERENCES messages(id),
  is_unsent boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  read_at timestamptz
);

-- Create message reactions table if it doesn't exist
CREATE TABLE IF NOT EXISTS message_reactions (
  message_id uuid REFERENCES messages(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  reaction text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);

-- Create message receipts table if it doesn't exist
CREATE TABLE IF NOT EXISTS message_receipts (
  message_id uuid REFERENCES messages(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  status message_status NOT NULL DEFAULT 'sent',
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);

-- Create improved message policies
CREATE POLICY "messages_select_policy"
  ON messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM conversation_participants cp
      WHERE cp.conversation_id = messages.conversation_id
      AND cp.user_id = auth.uid()
    )
  );

CREATE POLICY "messages_insert_policy"
  ON messages FOR INSERT
  WITH CHECK (
    -- Sender must be the authenticated user
    sender_id = auth.uid()
    -- Must be a participant in the conversation
    AND EXISTS (
      SELECT 1 FROM conversation_participants cp
      WHERE cp.conversation_id = messages.conversation_id
      AND cp.user_id = auth.uid()
    )
    -- Receiver must be a participant in the conversation
    AND EXISTS (
      SELECT 1 FROM conversation_participants cp
      WHERE cp.conversation_id = messages.conversation_id
      AND cp.user_id = receiver_id
    )
  );

CREATE POLICY "messages_update_policy"
  ON messages FOR UPDATE
  USING (sender_id = auth.uid());

CREATE POLICY "messages_delete_policy"
  ON messages FOR DELETE
  USING (sender_id = auth.uid());

-- Create function to send message with proper error handling
CREATE OR REPLACE FUNCTION send_message(
  target_conversation_id text,
  target_receiver_id uuid,
  content text,
  message_type message_type DEFAULT 'text',
  media_url text DEFAULT NULL,
  reply_to_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  message_id uuid;
  v_conversation_exists boolean;
  v_sender_participant boolean;
  v_receiver_participant boolean;
BEGIN
  -- Check if conversation exists
  SELECT EXISTS (
    SELECT 1 FROM conversations 
    WHERE id = target_conversation_id
  ) INTO v_conversation_exists;

  IF NOT v_conversation_exists THEN
    RAISE EXCEPTION 'Conversation does not exist';
  END IF;

  -- Check if sender is participant
  SELECT EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_id = target_conversation_id
    AND user_id = auth.uid()
  ) INTO v_sender_participant;

  IF NOT v_sender_participant THEN
    RAISE EXCEPTION 'Sender is not a participant in this conversation';
  END IF;

  -- Check if receiver is participant
  SELECT EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_id = target_conversation_id
    AND user_id = target_receiver_id
  ) INTO v_receiver_participant;

  IF NOT v_receiver_participant THEN
    RAISE EXCEPTION 'Receiver is not a participant in this conversation';
  END IF;

  -- Create message
  INSERT INTO messages (
    conversation_id,
    sender_id,
    receiver_id,
    content,
    message_type,
    media_url,
    reply_to_id
  )
  VALUES (
    target_conversation_id,
    auth.uid(),
    target_receiver_id,
    content,
    message_type,
    media_url,
    reply_to_id
  )
  RETURNING id INTO message_id;

  -- Update conversation last_message_at
  UPDATE conversations
  SET 
    last_message_at = now(),
    updated_at = now()
  WHERE id = target_conversation_id;

  -- Create receipts for all participants
  INSERT INTO message_receipts (message_id, user_id, status)
  SELECT 
    message_id,
    user_id,
    CASE 
      WHEN user_id = auth.uid() THEN 'seen'::message_status
      ELSE 'sent'::message_status
    END
  FROM conversation_participants
  WHERE conversation_id = target_conversation_id;

  RETURN message_id;
END;
$$;