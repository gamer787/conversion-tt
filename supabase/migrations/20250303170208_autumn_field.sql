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
  last_message_at timestamptz
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

-- Drop existing functions to avoid conflicts
DROP FUNCTION IF EXISTS start_conversation(uuid[], text, boolean);
DROP FUNCTION IF EXISTS send_message(text, uuid, text, message_type, text, uuid);

-- Create function to start conversation
CREATE OR REPLACE FUNCTION start_conversation(
  participant_ids uuid[],
  title text DEFAULT NULL,
  is_group boolean DEFAULT false
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  conversation_id text;
BEGIN
  -- Validate participants
  IF NOT is_group AND array_length(participant_ids, 1) != 2 THEN
    RAISE EXCEPTION 'Direct messages must have exactly 2 participants';
  END IF;

  IF NOT is_group THEN
    -- Check if conversation already exists
    SELECT c.id INTO conversation_id
    FROM conversations c
    JOIN conversation_participants p1 ON p1.conversation_id = c.id
    JOIN conversation_participants p2 ON p2.conversation_id = c.id
    WHERE NOT c.is_group
    AND p1.user_id = participant_ids[1]
    AND p2.user_id = participant_ids[2];

    IF FOUND THEN
      RETURN conversation_id;
    END IF;
  END IF;

  -- Create new conversation
  INSERT INTO conversations (title, is_group)
  VALUES (title, is_group)
  RETURNING id INTO conversation_id;

  -- Add participants
  INSERT INTO conversation_participants (conversation_id, user_id, is_admin)
  SELECT 
    conversation_id,
    unnest(participant_ids),
    CASE WHEN unnest(participant_ids) = auth.uid() THEN true ELSE false END;

  RETURN conversation_id;
END;
$$;

-- Create function to send message
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