/*
  # Fix Messaging System Schema

  1. New Tables
    - conversations: Stores chat conversations
    - conversation_participants: Tracks users in each conversation
    - messages: Stores chat messages
    - message_reactions: Stores reactions to messages
    - message_receipts: Tracks message delivery/read status
    - typing_status: Tracks who is currently typing

  2. Security
    - RLS policies for all tables
    - Participants can only access their conversations
    - Message senders can unsend their own messages
    - Typing status visible to conversation participants

  3. Functions
    - get_conversations_v3(): Returns user's conversations with latest messages
    - get_messages_with_info(): Returns messages with sender info
    - send_message(): Sends a new message
    - mark_messages_seen(): Marks messages as seen
    - update_typing_status(): Updates user's typing status
*/

-- Drop existing policies if they exist
DO $$ 
BEGIN
  -- Drop policies for conversations
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'conversations' AND policyname = 'create_conversations_policy') THEN
    DROP POLICY create_conversations_policy ON conversations;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'conversations' AND policyname = 'view_conversations_policy') THEN
    DROP POLICY view_conversations_policy ON conversations;
  END IF;

  -- Drop policies for conversation_participants
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'conversation_participants' AND policyname = 'view_participants_policy') THEN
    DROP POLICY view_participants_policy ON conversation_participants;
  END IF;

  -- Drop policies for messages
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'messages' AND policyname = 'messages_insert_policy') THEN
    DROP POLICY messages_insert_policy ON messages;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'messages' AND policyname = 'messages_select_policy') THEN
    DROP POLICY messages_select_policy ON messages;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'messages' AND policyname = 'messages_update_policy') THEN
    DROP POLICY messages_update_policy ON messages;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'messages' AND policyname = 'messages_delete_policy') THEN
    DROP POLICY messages_delete_policy ON messages;
  END IF;
END $$;

-- Create enums if they don't exist
DO $$ BEGIN
  CREATE TYPE message_type AS ENUM (
    'text',
    'image',
    'video',
    'voice',
    'gif',
    'sticker'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE message_status AS ENUM (
    'sent',
    'delivered',
    'seen'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create tables
CREATE TABLE IF NOT EXISTS conversations (
  id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  title text,
  is_group boolean DEFAULT false NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  last_message_at timestamptz,
  encryption_key text
);

CREATE TABLE IF NOT EXISTS conversation_participants (
  conversation_id text NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  joined_at timestamptz DEFAULT now() NOT NULL,
  last_read_at timestamptz,
  is_admin boolean DEFAULT false NOT NULL,
  PRIMARY KEY (conversation_id, user_id)
);

CREATE TABLE IF NOT EXISTS messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id text NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES profiles(id) ON DELETE SET NULL,
  receiver_id uuid REFERENCES profiles(id),
  message_type message_type DEFAULT 'text'::message_type NOT NULL,
  content text,
  media_url text,
  reply_to_id uuid REFERENCES messages(id),
  is_unsent boolean DEFAULT false NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  read_at timestamptz
);

CREATE TABLE IF NOT EXISTS message_reactions (
  message_id uuid NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reaction text NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (message_id, user_id)
);

CREATE TABLE IF NOT EXISTS message_receipts (
  message_id uuid NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status message_status DEFAULT 'sent'::message_status NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (message_id, user_id)
);

CREATE TABLE IF NOT EXISTS typing_status (
  conversation_id text NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  started_at timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (conversation_id, user_id)
);

-- Create indices
CREATE INDEX IF NOT EXISTS idx_conversation_participants_user ON conversation_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver ON messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_reply ON messages(reply_to_id) WHERE reply_to_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_message_reactions_message ON message_reactions(message_id);
CREATE INDEX IF NOT EXISTS idx_message_receipts_message ON message_receipts(message_id);
CREATE INDEX IF NOT EXISTS idx_typing_status_conversation ON typing_status(conversation_id);

-- Enable RLS
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE typing_status ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "create_conversations_policy_v3" ON conversations
  FOR INSERT TO public
  WITH CHECK (true);

CREATE POLICY "view_conversations_policy_v3" ON conversations
  FOR SELECT TO public
  USING (EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_participants.conversation_id = conversations.id
    AND conversation_participants.user_id = auth.uid()
  ));

CREATE POLICY "view_participants_policy_v3" ON conversation_participants
  FOR SELECT TO public
  USING (user_id = auth.uid());

CREATE POLICY "messages_insert_policy_v3" ON messages
  FOR INSERT TO public
  WITH CHECK (
    sender_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM conversation_participants cp
      WHERE cp.conversation_id = messages.conversation_id
      AND cp.user_id = auth.uid()
    )
  );

CREATE POLICY "messages_select_policy_v3" ON messages
  FOR SELECT TO public
  USING (
    EXISTS (
      SELECT 1 FROM conversation_participants cp
      WHERE cp.conversation_id = messages.conversation_id
      AND cp.user_id = auth.uid()
    )
  );

CREATE POLICY "messages_update_policy_v3" ON messages
  FOR UPDATE TO public
  USING (sender_id = auth.uid())
  WITH CHECK (sender_id = auth.uid());

CREATE POLICY "messages_delete_policy_v3" ON messages
  FOR DELETE TO public
  USING (sender_id = auth.uid());

-- Create functions
CREATE OR REPLACE FUNCTION get_conversations_v3()
RETURNS TABLE (
  id text,
  title text,
  is_group boolean,
  created_at timestamptz,
  updated_at timestamptz,
  last_message_at timestamptz,
  unread_count bigint,
  participants jsonb,
  latest_message jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH user_conversations AS (
    SELECT DISTINCT cp.conversation_id
    FROM conversation_participants cp
    WHERE cp.user_id = auth.uid()
  ),
  conversation_details AS (
    SELECT 
      c.id,
      c.title,
      c.is_group,
      c.created_at,
      c.updated_at,
      c.last_message_at,
      (
        SELECT COUNT(*)
        FROM messages m
        WHERE m.conversation_id = c.id
        AND m.created_at > COALESCE(cp.last_read_at, '1970-01-01'::timestamptz)
        AND m.sender_id != auth.uid()
      ) as unread_count,
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'user_id', p.id,
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
          )
        )
        FROM conversation_participants cp2
        JOIN profiles p ON p.id = cp2.user_id
        WHERE cp2.conversation_id = c.id
        AND cp2.user_id != auth.uid()
      ) as participants,
      (
        SELECT jsonb_build_object(
          'id', m.id,
          'sender_id', m.sender_id,
          'content', m.content,
          'message_type', m.message_type,
          'created_at', m.created_at,
          'is_unsent', m.is_unsent,
          'sender_info', jsonb_build_object(
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
          )
        )
        FROM messages m
        JOIN profiles p ON p.id = m.sender_id
        WHERE m.conversation_id = c.id
        ORDER BY m.created_at DESC
        LIMIT 1
      ) as latest_message
    FROM conversations c
    JOIN conversation_participants cp ON cp.conversation_id = c.id
    WHERE c.id IN (SELECT conversation_id FROM user_conversations)
    AND cp.user_id = auth.uid()
  )
  SELECT *
  FROM conversation_details
  ORDER BY last_message_at DESC NULLS LAST;
END;
$$;

CREATE OR REPLACE FUNCTION get_messages_with_info(target_conversation_id text)
RETURNS TABLE (
  id uuid,
  conversation_id text,
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
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify user is participant
  IF NOT EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_id = target_conversation_id
    AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  SELECT 
    m.id,
    m.conversation_id,
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
          mr.reaction,
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
$$;

CREATE OR REPLACE FUNCTION send_message(
  target_conversation_id text,
  target_receiver_id uuid,
  content text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_message_id uuid;
BEGIN
  -- Verify user is participant
  IF NOT EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_id = target_conversation_id
    AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  -- Insert message
  INSERT INTO messages (
    conversation_id,
    sender_id,
    receiver_id,
    content
  ) VALUES (
    target_conversation_id,
    auth.uid(),
    target_receiver_id,
    content
  )
  RETURNING id INTO new_message_id;

  -- Update conversation last_message_at
  UPDATE conversations
  SET last_message_at = now()
  WHERE id = target_conversation_id;

  -- Create message receipts for all participants
  INSERT INTO message_receipts (message_id, user_id, status)
  SELECT 
    new_message_id,
    cp.user_id,
    CASE 
      WHEN cp.user_id = auth.uid() THEN 'seen'::message_status
      ELSE 'sent'::message_status
    END
  FROM conversation_participants cp
  WHERE cp.conversation_id = target_conversation_id;

  RETURN new_message_id;
END;
$$;

CREATE OR REPLACE FUNCTION mark_messages_seen(target_conversation_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Update participant's last_read_at
  UPDATE conversation_participants
  SET last_read_at = now()
  WHERE conversation_id = target_conversation_id
  AND user_id = auth.uid();

  -- Update message receipts
  UPDATE message_receipts mr
  SET status = 'seen'::message_status
  FROM messages m
  WHERE m.id = mr.message_id
  AND m.conversation_id = target_conversation_id
  AND mr.user_id = auth.uid()
  AND m.sender_id != auth.uid();
END;
$$;

CREATE OR REPLACE FUNCTION update_typing_status(
  target_conversation_id text,
  is_typing boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
$$;

-- Cleanup job for old typing status
CREATE OR REPLACE FUNCTION cleanup_typing_status()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM typing_status
  WHERE started_at < now() - interval '10 seconds';
END;
$$;