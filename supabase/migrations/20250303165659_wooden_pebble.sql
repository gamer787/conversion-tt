-- Drop existing functions
DROP FUNCTION IF EXISTS get_messages_with_info;
DROP FUNCTION IF EXISTS mark_messages_seen;
DROP FUNCTION IF EXISTS send_message;

-- Add receiver_id column to messages if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'messages' AND column_name = 'receiver_id'
  ) THEN
    ALTER TABLE messages ADD COLUMN receiver_id uuid REFERENCES profiles(id);
  END IF;
END $$;

-- Create function to get messages with badges
CREATE OR REPLACE FUNCTION get_messages_with_info(
  target_conversation_id text,
  limit_val integer DEFAULT 50,
  before_timestamp timestamptz DEFAULT now()
)
RETURNS TABLE (
  id uuid,
  sender_id uuid,
  receiver_id uuid,
  content text,
  message_type message_type,
  media_url text,
  reply_to_id uuid,
  is_unsent boolean,
  created_at timestamptz,
  updated_at timestamptz,
  read_at timestamptz,
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
    WHERE conversation_id = target_conversation_id
    AND user_id = auth.uid()
  ) THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH user_badges AS (
    SELECT DISTINCT ON (bs.user_id)
      bs.user_id,
      jsonb_build_object('role', bs.role) as badge
    FROM badge_subscriptions bs
    WHERE now() BETWEEN bs.start_date AND bs.end_date
      AND bs.cancelled_at IS NULL
    ORDER BY bs.user_id, bs.end_date DESC
  )
  SELECT 
    m.id,
    m.sender_id,
    m.receiver_id,
    m.content,
    m.message_type,
    m.media_url,
    m.reply_to_id,
    m.is_unsent,
    m.created_at,
    m.updated_at,
    m.read_at,
    jsonb_build_object(
      'username', p.username,
      'display_name', p.display_name,
      'avatar_url', p.avatar_url,
      'badge', COALESCE(ub.badge, null)
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
        FROM messages m2
        JOIN profiles p2 ON p2.id != m.sender_id
        WHERE m2.id = m.id
        AND m2.read_at IS NOT NULL
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
  LEFT JOIN user_badges ub ON ub.user_id = m.sender_id
  LEFT JOIN message_reactions mr ON mr.message_id = m.id
  LEFT JOIN profiles mr_p ON mr_p.id = mr.user_id
  WHERE m.conversation_id = target_conversation_id
  AND m.created_at < before_timestamp
  GROUP BY 
    m.id, m.sender_id, m.receiver_id, m.content, m.message_type, 
    m.media_url, m.reply_to_id, m.is_unsent, 
    m.created_at, m.updated_at, m.read_at,
    p.username, p.display_name, p.avatar_url,
    ub.badge
  ORDER BY m.created_at DESC
  LIMIT limit_val;
END;
$$;

-- Create function to mark messages as seen
CREATE OR REPLACE FUNCTION mark_messages_seen(
  target_conversation_id text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Update messages read_at
  UPDATE messages
  SET read_at = now()
  WHERE conversation_id = target_conversation_id
  AND read_at IS NULL
  AND sender_id != auth.uid();

  -- Update participant's last_read_at
  UPDATE conversation_participants
  SET last_read_at = now()
  WHERE conversation_id = target_conversation_id
  AND user_id = auth.uid();
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
BEGIN
  -- Verify sender is in conversation
  IF NOT EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_id = target_conversation_id
    AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'User is not a participant in this conversation';
  END IF;

  -- Verify receiver is in conversation
  IF NOT EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_id = target_conversation_id
    AND user_id = target_receiver_id
  ) THEN
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

-- Drop existing message policies
DROP POLICY IF EXISTS "messages_select_policy" ON messages;
DROP POLICY IF EXISTS "messages_insert_policy" ON messages;
DROP POLICY IF EXISTS "messages_update_policy" ON messages;
DROP POLICY IF EXISTS "messages_delete_policy" ON messages;

-- Create improved message policies
CREATE POLICY "messages_select_policy"
  ON messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM conversation_participants
      WHERE conversation_id = messages.conversation_id
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "messages_insert_policy"
  ON messages FOR INSERT
  WITH CHECK (
    -- Sender must be the authenticated user
    sender_id = auth.uid()
    -- Must be a participant in the conversation
    AND EXISTS (
      SELECT 1 FROM conversation_participants
      WHERE conversation_id = messages.conversation_id
      AND user_id = auth.uid()
    )
    -- Receiver must be a participant in the conversation
    AND (
      receiver_id IS NULL 
      OR EXISTS (
        SELECT 1 FROM conversation_participants
        WHERE conversation_id = messages.conversation_id
        AND user_id = receiver_id
      )
    )
  );

CREATE POLICY "messages_update_policy"
  ON messages FOR UPDATE
  USING (sender_id = auth.uid());

CREATE POLICY "messages_delete_policy"
  ON messages FOR DELETE
  USING (sender_id = auth.uid());