-- Drop existing objects in the correct order
DROP TABLE IF EXISTS typing_status CASCADE;
DROP TABLE IF EXISTS message_reactions CASCADE;
DROP TABLE IF EXISTS message_receipts CASCADE;
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS conversation_participants CASCADE;
DROP TABLE IF EXISTS conversations CASCADE;
DROP TYPE IF EXISTS message_type CASCADE;
DROP TYPE IF EXISTS message_status CASCADE;

-- Create message types enum
CREATE TYPE message_type AS ENUM (
  'text',
  'image',
  'video',
  'voice',
  'gif',
  'sticker'
);

-- Create message status enum
CREATE TYPE message_status AS ENUM (
  'sent',
  'delivered',
  'seen'
);

-- Create conversations table
CREATE TABLE conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text, -- Optional, for group chats
  is_group boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  last_message_at timestamptz,
  encryption_key text -- For E2E encryption
);

-- Create conversation participants table
CREATE TABLE conversation_participants (
  conversation_id uuid REFERENCES conversations(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(),
  last_read_at timestamptz,
  is_admin boolean NOT NULL DEFAULT false,
  PRIMARY KEY (conversation_id, user_id)
);

-- Create messages table
CREATE TABLE messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid REFERENCES conversations(id) ON DELETE CASCADE NOT NULL,
  sender_id uuid REFERENCES profiles(id) ON DELETE SET NULL NOT NULL,
  message_type message_type NOT NULL DEFAULT 'text',
  content text, -- Encrypted content
  media_url text, -- For image/video/voice messages
  reply_to_id uuid REFERENCES messages(id),
  is_unsent boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Create message reactions table
CREATE TABLE message_reactions (
  message_id uuid REFERENCES messages(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  reaction text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);

-- Create message receipts table
CREATE TABLE message_receipts (
  message_id uuid REFERENCES messages(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  status message_status NOT NULL DEFAULT 'sent',
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);

-- Create typing status table
CREATE TABLE typing_status (
  conversation_id uuid REFERENCES conversations(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  started_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (conversation_id, user_id)
);

-- Enable RLS
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE typing_status ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view their conversations"
  ON conversations FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM conversation_participants
      WHERE conversation_id = conversations.id
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create conversations"
  ON conversations FOR INSERT
  WITH CHECK (true); -- Additional checks in functions

CREATE POLICY "Users can view conversations they're part of"
  ON conversation_participants FOR SELECT
  USING (
    user_id = auth.uid()
    OR conversation_id IN (
      SELECT conversation_id FROM conversation_participants
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can view messages in their conversations"
  ON messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM conversation_participants
      WHERE conversation_id = messages.conversation_id
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "Users can send messages to their conversations"
  ON messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM conversation_participants
      WHERE conversation_id = messages.conversation_id
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update their own messages"
  ON messages FOR UPDATE
  USING (sender_id = auth.uid());

CREATE POLICY "Users can react to messages in their conversations"
  ON message_reactions FOR ALL
  USING (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM conversation_participants
      WHERE conversation_id = (
        SELECT conversation_id FROM messages
        WHERE id = message_reactions.message_id
      )
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update message receipts"
  ON message_receipts FOR ALL
  USING (user_id = auth.uid());

CREATE POLICY "Users can update typing status"
  ON typing_status FOR ALL
  USING (user_id = auth.uid());

-- Create indexes
CREATE INDEX idx_conversation_participants_user 
ON conversation_participants(user_id);

CREATE INDEX idx_messages_conversation 
ON messages(conversation_id);

CREATE INDEX idx_messages_sender 
ON messages(sender_id);

CREATE INDEX idx_messages_reply 
ON messages(reply_to_id) 
WHERE reply_to_id IS NOT NULL;

CREATE INDEX idx_message_reactions_message 
ON message_reactions(message_id);

CREATE INDEX idx_message_receipts_message 
ON message_receipts(message_id);

CREATE INDEX idx_typing_status_conversation 
ON typing_status(conversation_id);

-- Create function to start a conversation
CREATE OR REPLACE FUNCTION start_conversation(
  participant_ids uuid[],
  title text DEFAULT NULL,
  is_group boolean DEFAULT false
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  conversation_id uuid;
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

-- Create function to send a message
CREATE OR REPLACE FUNCTION send_message(
  conversation_id uuid,
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
BEGIN
  -- Verify sender is in conversation
  IF NOT EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_id = conversation_id
    AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'User is not a participant in this conversation';
  END IF;

  -- Create message
  INSERT INTO messages (
    conversation_id,
    sender_id,
    content,
    message_type,
    media_url,
    reply_to_id
  )
  VALUES (
    conversation_id,
    auth.uid(),
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
  WHERE id = conversation_id;

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
  WHERE conversation_id = conversation_id;

  RETURN message_id;
END;
$$;

-- Create function to mark messages as seen
CREATE OR REPLACE FUNCTION mark_messages_seen(conversation_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Update message receipts
  UPDATE message_receipts mr
  SET 
    status = 'seen',
    updated_at = now()
  FROM messages m
  WHERE m.id = mr.message_id
  AND m.conversation_id = conversation_id
  AND mr.user_id = auth.uid()
  AND mr.status != 'seen';

  -- Update participant's last_read_at
  UPDATE conversation_participants
  SET last_read_at = now()
  WHERE conversation_id = conversation_id
  AND user_id = auth.uid();
END;
$$;

-- Create function to get conversations with latest messages
CREATE OR REPLACE FUNCTION get_conversations(
  limit_val integer DEFAULT 20,
  offset_val integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
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
    SELECT c.*
    FROM conversations c
    JOIN conversation_participants cp ON cp.conversation_id = c.id
    WHERE cp.user_id = auth.uid()
    ORDER BY c.last_message_at DESC NULLS LAST
    LIMIT limit_val
    OFFSET offset_val
  ),
  conversation_messages AS (
    SELECT DISTINCT ON (m.conversation_id)
      m.conversation_id,
      jsonb_build_object(
        'id', m.id,
        'sender_id', m.sender_id,
        'content', m.content,
        'type', m.message_type,
        'created_at', m.created_at,
        'is_unsent', m.is_unsent
      ) as message
    FROM messages m
    WHERE m.conversation_id IN (SELECT id FROM user_conversations)
    ORDER BY m.conversation_id, m.created_at DESC
  ),
  unread_counts AS (
    SELECT 
      m.conversation_id,
      COUNT(*) as count
    FROM messages m
    LEFT JOIN message_receipts mr ON mr.message_id = m.id
    WHERE m.conversation_id IN (SELECT id FROM user_conversations)
    AND mr.user_id = auth.uid()
    AND mr.status != 'seen'
    GROUP BY m.conversation_id
  )
  SELECT 
    uc.id,
    uc.title,
    uc.is_group,
    uc.created_at,
    uc.updated_at,
    uc.last_message_at,
    COALESCE(un.count, 0) as unread_count,
    (
      SELECT jsonb_agg(
        jsonb_build_object(
          'user_id', p.id,
          'username', p.username,
          'display_name', p.display_name,
          'avatar_url', p.avatar_url
        )
      )
      FROM conversation_participants cp
      JOIN profiles p ON p.id = cp.user_id
      WHERE cp.conversation_id = uc.id
    ) as participants,
    cm.message as latest_message
  FROM user_conversations uc
  LEFT JOIN conversation_messages cm ON cm.conversation_id = uc.id
  LEFT JOIN unread_counts un ON un.conversation_id = uc.id;
END;
$$;

-- Create function to search messages
CREATE OR REPLACE FUNCTION search_messages(
  conversation_id uuid,
  search_query text,
  limit_val integer DEFAULT 20
)
RETURNS TABLE (
  id uuid,
  sender_id uuid,
  content text,
  message_type message_type,
  media_url text,
  reply_to_id uuid,
  created_at timestamptz,
  sender_info jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify user is in conversation
  IF NOT EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_id = conversation_id
    AND user_id = auth.uid()
  ) THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT 
    m.id,
    m.sender_id,
    m.content,
    m.message_type,
    m.media_url,
    m.reply_to_id,
    m.created_at,
    jsonb_build_object(
      'username', p.username,
      'display_name', p.display_name,
      'avatar_url', p.avatar_url
    ) as sender_info
  FROM messages m
  JOIN profiles p ON p.id = m.sender_id
  WHERE m.conversation_id = conversation_id
  AND m.content ILIKE '%' || search_query || '%'
  AND NOT m.is_unsent
  ORDER BY m.created_at DESC
  LIMIT limit_val;
END;
$$;

-- Create function to update typing status
CREATE OR REPLACE FUNCTION update_typing_status(
  conversation_id uuid,
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
    VALUES (conversation_id, auth.uid())
    ON CONFLICT (conversation_id, user_id)
    DO UPDATE SET started_at = now();
  ELSE
    DELETE FROM typing_status
    WHERE conversation_id = conversation_id
    AND user_id = auth.uid();
  END IF;
END;
$$;

-- Create function to unsend message
CREATE OR REPLACE FUNCTION unsend_message(message_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE messages
  SET 
    is_unsent = true,
    content = NULL,
    media_url = NULL,
    updated_at = now()
  WHERE id = message_id
  AND sender_id = auth.uid()
  AND created_at > now() - interval '1 hour';

  RETURN FOUND;
END;
$$;

-- Create function to add reaction
CREATE OR REPLACE FUNCTION add_reaction(
  message_id uuid,
  reaction text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO message_reactions (message_id, user_id, reaction)
  VALUES (message_id, auth.uid(), reaction)
  ON CONFLICT (message_id, user_id)
  DO UPDATE SET 
    reaction = EXCLUDED.reaction,
    created_at = now();
END;
$$;

-- Create function to remove reaction
CREATE OR REPLACE FUNCTION remove_reaction(message_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM message_reactions
  WHERE message_id = message_id
  AND user_id = auth.uid();
END;
$$;

-- Create function to get conversation messages
CREATE OR REPLACE FUNCTION get_conversation_messages(
  conversation_id uuid,
  limit_val integer DEFAULT 50,
  before_timestamp timestamptz DEFAULT now()
)
RETURNS TABLE (
  id uuid,
  sender_id uuid,
  content text,
  message_type message_type,
  media_url text,
  reply_to_id uuid,
  is_unsent boolean,
  created_at timestamptz,
  updated_at timestamptz,
  sender_info jsonb,
  reactions jsonb,
  receipt_status jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify user is in conversation
  IF NOT EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_id = conversation_id
    AND user_id = auth.uid()
  ) THEN
    RETURN;
  END IF;

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
    m.updated_at,
    jsonb_build_object(
      'username', p.username,
      'display_name', p.display_name,
      'avatar_url', p.avatar_url
    ) as sender_info,
    COALESCE(
      jsonb_object_agg(
        DISTINCT mr.reaction,
        jsonb_build_object(
          'count', COUNT(*) OVER (PARTITION BY mr.reaction),
          'users', jsonb_agg(DISTINCT jsonb_build_object(
            'user_id', mr_p.id,
            'username', mr_p.username
          )) OVER (PARTITION BY mr.reaction)
        )
      ) FILTER (WHERE mr.reaction IS NOT NULL),
      '{}'::jsonb
    ) as reactions,
    jsonb_build_object(
      'seen_by', (
        SELECT jsonb_agg(DISTINCT p2.username)
        FROM message_receipts mr2
        JOIN profiles p2 ON p2.id = mr2.user_id
        WHERE mr2.message_id = m.id
        AND mr2.status = 'seen'
      ),
      'delivered_to', (
        SELECT jsonb_agg(DISTINCT p3.username)
        FROM message_receipts mr3
        JOIN profiles p3 ON p3.id = mr3.user_id
        WHERE mr3.message_id = m.id
        AND mr3.status = 'delivered'
      )
    ) as receipt_status
  FROM messages m
  JOIN profiles p ON p.id = m.sender_id
  LEFT JOIN message_reactions mr ON mr.message_id = m.id
  LEFT JOIN profiles mr_p ON mr_p.id = mr.user_id
  WHERE m.conversation_id = conversation_id
  AND m.created_at < before_timestamp
  GROUP BY 
    m.id, m.sender_id, m.content, m.message_type, 
    m.media_url, m.reply_to_id, m.is_unsent, 
    m.created_at, m.updated_at,
    p.username, p.display_name, p.avatar_url
  ORDER BY m.created_at DESC
  LIMIT limit_val;
END;
$$;