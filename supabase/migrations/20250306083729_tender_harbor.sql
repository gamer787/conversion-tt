/*
  # Messaging System Migration

  This migration adds tables and functions for a real-time messaging system.

  1. New Types
    - message_status: sent, delivered, seen
    - message_type: text, image, gif, sticker, video, voice

  2. New Tables
    - conversations
    - conversation_participants
    - messages
    - message_reactions
    - message_receipts
    - typing_status

  3. New Functions
    - get_conversations_v4
    - get_messages_with_info_v4
    - send_message_v4
    - mark_messages_seen_v4
    - update_typing_status_v4

  4. Security
    - RLS policies for all tables
    - Execute permissions for functions
*/

-- Drop existing functions if they exist
DO $$ BEGIN
  DROP FUNCTION IF EXISTS get_conversations();
  DROP FUNCTION IF EXISTS get_conversations_v2();
  DROP FUNCTION IF EXISTS get_conversations_v3();
  DROP FUNCTION IF EXISTS get_messages_with_info(text);
  DROP FUNCTION IF EXISTS get_messages_with_info_v2(text);
  DROP FUNCTION IF EXISTS get_messages_with_info_v3(text);
  DROP FUNCTION IF EXISTS send_message(text, uuid, text, message_type, text, uuid);
  DROP FUNCTION IF EXISTS send_message_v2(text, uuid, text, message_type, text, uuid);
  DROP FUNCTION IF EXISTS send_message_v3(text, uuid, text, message_type, text, uuid);
  DROP FUNCTION IF EXISTS mark_messages_seen(text);
  DROP FUNCTION IF EXISTS mark_messages_seen_v2(text);
  DROP FUNCTION IF EXISTS mark_messages_seen_v3(text);
  DROP FUNCTION IF EXISTS update_typing_status(text, boolean);
  DROP FUNCTION IF EXISTS update_typing_status_v2(text, boolean);
  DROP FUNCTION IF EXISTS update_typing_status_v3(text, boolean);
EXCEPTION
  WHEN undefined_function THEN NULL;
END $$;

-- Create message_status type if not exists
DO $$ BEGIN
  CREATE TYPE message_status AS ENUM ('sent', 'delivered', 'seen');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Create message_type type if not exists
DO $$ BEGIN
  CREATE TYPE message_type AS ENUM ('text', 'image', 'gif', 'sticker', 'video', 'voice');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Conversations Table
CREATE TABLE IF NOT EXISTS conversations (
  id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  title text,
  is_group boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  last_message_at timestamptz,
  encryption_key text
);

-- Conversation Participants Table
CREATE TABLE IF NOT EXISTS conversation_participants (
  conversation_id text REFERENCES conversations(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  joined_at timestamptz DEFAULT now(),
  last_read_at timestamptz,
  is_admin boolean DEFAULT false,
  PRIMARY KEY (conversation_id, user_id)
);

-- Messages Table
CREATE TABLE IF NOT EXISTS messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id text REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  receiver_id uuid REFERENCES profiles(id),
  message_type message_type DEFAULT 'text'::message_type,
  content text,
  media_url text,
  reply_to_id uuid REFERENCES messages(id),
  is_unsent boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  read_at timestamptz
);

-- Message Reactions Table
CREATE TABLE IF NOT EXISTS message_reactions (
  message_id uuid REFERENCES messages(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  reaction text NOT NULL,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);

-- Message Receipts Table
CREATE TABLE IF NOT EXISTS message_receipts (
  message_id uuid REFERENCES messages(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  status message_status DEFAULT 'sent'::message_status,
  updated_at timestamptz DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);

-- Typing Status Table
CREATE TABLE IF NOT EXISTS typing_status (
  conversation_id text REFERENCES conversations(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  started_at timestamptz DEFAULT now(),
  PRIMARY KEY (conversation_id, user_id)
);

-- Get Conversations Function (v4)
CREATE OR REPLACE FUNCTION get_conversations_v4()
RETURNS TABLE (
  id text,
  title text,
  is_group boolean,
  last_message_at timestamptz,
  unread_count bigint,
  participants jsonb,
  latest_message jsonb
) SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  WITH user_conversations AS (
    SELECT DISTINCT c.id
    FROM conversations c
    JOIN conversation_participants cp ON cp.conversation_id = c.id
    WHERE cp.user_id = auth.uid()
  ),
  unread_counts AS (
    SELECT 
      m.conversation_id,
      COUNT(*) as unread
    FROM messages m
    JOIN conversation_participants cp ON cp.conversation_id = m.conversation_id
    WHERE cp.user_id = auth.uid()
      AND (cp.last_read_at IS NULL OR m.created_at > cp.last_read_at)
    GROUP BY m.conversation_id
  )
  SELECT 
    c.id,
    c.title,
    c.is_group,
    c.last_message_at,
    COALESCE(uc.unread, 0) as unread_count,
    (
      SELECT jsonb_agg(
        jsonb_build_object(
          'user_id', p.id,
          'username', p.username,
          'display_name', p.display_name,
          'avatar_url', p.avatar_url
        )
      )
      FROM conversation_participants cp2
      JOIN profiles p ON p.id = cp2.user_id
      WHERE cp2.conversation_id = c.id
    ) as participants,
    (
      SELECT jsonb_build_object(
        'id', m.id,
        'sender_id', m.sender_id,
        'content', m.content,
        'message_type', m.message_type,
        'is_unsent', m.is_unsent,
        'created_at', m.created_at
      )
      FROM messages m
      WHERE m.conversation_id = c.id
      ORDER BY m.created_at DESC
      LIMIT 1
    ) as latest_message
  FROM conversations c
  JOIN user_conversations uc2 ON uc2.id = c.id
  LEFT JOIN unread_counts uc ON uc.conversation_id = c.id
  ORDER BY c.last_message_at DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql;

-- Get Messages Function (v4)
CREATE OR REPLACE FUNCTION get_messages_with_info_v4(target_conversation_id text)
RETURNS TABLE (
  id uuid,
  sender_id uuid,
  content text,
  message_type message_type,
  media_url text,
  reply_to_id uuid,
  is_unsent boolean,
  created_at timestamptz,
  read_at timestamptz,
  sender_info jsonb,
  reactions jsonb
) SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT 
    m.id,
    m.sender_id,
    m.content,
    m.message_type,
    m.media_url,
    m.reply_to_id,
    m.is_unsent,
    m.created_at,
    m.read_at,
    jsonb_build_object(
      'username', p.username,
      'display_name', p.display_name,
      'avatar_url', p.avatar_url,
      'badge', (
        SELECT jsonb_build_object('role', bs.role)
        FROM badge_subscriptions bs
        WHERE bs.user_id = p.id
          AND bs.start_date <= now()
          AND bs.end_date > now()
          AND bs.cancelled_at IS NULL
        LIMIT 1
      )
    ) as sender_info,
    COALESCE(
      (
        SELECT jsonb_object_agg(
          reaction,
          jsonb_build_object(
            'count', COUNT(*),
            'users', jsonb_agg(
              jsonb_build_object(
                'user_id', p2.id,
                'username', p2.username
              )
            )
          )
        )
        FROM message_reactions mr
        JOIN profiles p2 ON p2.id = mr.user_id
        WHERE mr.message_id = m.id
        GROUP BY mr.message_id
      ),
      '{}'::jsonb
    ) as reactions
  FROM messages m
  JOIN profiles p ON p.id = m.sender_id
  WHERE m.conversation_id = target_conversation_id
  ORDER BY m.created_at ASC;
END;
$$ LANGUAGE plpgsql;

-- Send Message Function (v4)
CREATE OR REPLACE FUNCTION send_message_v4(
  target_conversation_id text,
  target_receiver_id uuid,
  content text,
  message_type message_type DEFAULT 'text',
  media_url text DEFAULT NULL,
  reply_to_id uuid DEFAULT NULL
) RETURNS uuid SECURITY DEFINER AS $$
DECLARE
  new_message_id uuid;
BEGIN
  -- Insert message
  INSERT INTO messages (
    conversation_id,
    sender_id,
    receiver_id,
    content,
    message_type,
    media_url,
    reply_to_id
  ) VALUES (
    target_conversation_id,
    auth.uid(),
    target_receiver_id,
    content,
    message_type,
    media_url,
    reply_to_id
  ) RETURNING id INTO new_message_id;

  -- Update conversation last_message_at
  UPDATE conversations
  SET last_message_at = now()
  WHERE id = target_conversation_id;

  -- Create initial receipt
  INSERT INTO message_receipts (message_id, user_id, status)
  VALUES (new_message_id, auth.uid(), 'sent');

  RETURN new_message_id;
END;
$$ LANGUAGE plpgsql;

-- Mark Messages Seen Function (v4)
CREATE OR REPLACE FUNCTION mark_messages_seen_v4(target_conversation_id text)
RETURNS void SECURITY DEFINER AS $$
BEGIN
  -- Update last_read_at for the participant
  UPDATE conversation_participants
  SET last_read_at = now()
  WHERE conversation_id = target_conversation_id
    AND user_id = auth.uid();

  -- Update message receipts
  INSERT INTO message_receipts (message_id, user_id, status)
  SELECT m.id, auth.uid(), 'seen'::message_status
  FROM messages m
  WHERE m.conversation_id = target_conversation_id
    AND m.sender_id != auth.uid()
  ON CONFLICT (message_id, user_id)
  DO UPDATE SET status = 'seen'::message_status, updated_at = now();
END;
$$ LANGUAGE plpgsql;

-- Update Typing Status Function (v4)
CREATE OR REPLACE FUNCTION update_typing_status_v4(
  target_conversation_id text,
  is_typing boolean
) RETURNS void SECURITY DEFINER AS $$
BEGIN
  IF is_typing THEN
    INSERT INTO typing_status (conversation_id, user_id)
    VALUES (target_conversation_id, auth.uid())
    ON CONFLICT (conversation_id, user_id)
    DO UPDATE SET started_at = now();
  ELSE
    DELETE FROM typing_status
    WHERE conversation_id = target_conversation_id
      AND user_id = auth.uid();
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Enable RLS
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE typing_status ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS create_conversations_policy ON conversations;
  DROP POLICY IF EXISTS view_conversations_policy ON conversations;
  DROP POLICY IF EXISTS view_participants_policy ON conversation_participants;
  DROP POLICY IF EXISTS messages_select_policy ON messages;
  DROP POLICY IF EXISTS messages_insert_policy ON messages;
  DROP POLICY IF EXISTS messages_update_policy ON messages;
  DROP POLICY IF EXISTS messages_delete_policy ON messages;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

-- Create RLS Policies
CREATE POLICY create_conversations_policy ON conversations
  FOR INSERT TO public
  WITH CHECK (true);

CREATE POLICY view_conversations_policy ON conversations
  FOR SELECT TO public
  USING (EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_id = id AND user_id = auth.uid()
  ));

CREATE POLICY view_participants_policy ON conversation_participants
  FOR SELECT TO public
  USING (user_id = auth.uid());

CREATE POLICY messages_select_policy ON messages
  FOR SELECT TO public
  USING (EXISTS (
    SELECT 1 FROM conversation_participants cp
    WHERE cp.conversation_id = messages.conversation_id
      AND cp.user_id = auth.uid()
  ));

CREATE POLICY messages_insert_policy ON messages
  FOR INSERT TO public
  WITH CHECK (
    sender_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM conversation_participants cp
      WHERE cp.conversation_id = messages.conversation_id
        AND cp.user_id = auth.uid()
    )
  );

CREATE POLICY messages_update_policy ON messages
  FOR UPDATE TO public
  USING (sender_id = auth.uid())
  WITH CHECK (sender_id = auth.uid());

CREATE POLICY messages_delete_policy ON messages
  FOR DELETE TO public
  USING (sender_id = auth.uid());

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_conversations_v4 TO public;
GRANT EXECUTE ON FUNCTION get_messages_with_info_v4 TO public;
GRANT EXECUTE ON FUNCTION send_message_v4 TO public;
GRANT EXECUTE ON FUNCTION mark_messages_seen_v4 TO public;
GRANT EXECUTE ON FUNCTION update_typing_status_v4 TO public;