-- Drop existing functions first
DROP FUNCTION IF EXISTS get_conversation_messages(uuid, integer, timestamptz);
DROP FUNCTION IF EXISTS mark_messages_seen(uuid);

-- Drop existing policies to prevent recursion
DROP POLICY IF EXISTS "Users can view conversations they're part of" ON conversation_participants;
DROP POLICY IF EXISTS "Users can view their conversations" ON conversations;

-- Create improved policies without recursion
CREATE POLICY "view_conversations_policy"
  ON conversations FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM conversation_participants
      WHERE conversation_id = id
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "view_participants_policy"
  ON conversation_participants FOR SELECT
  USING (user_id = auth.uid());

-- Add read_at column to messages
ALTER TABLE messages
ADD COLUMN IF NOT EXISTS read_at timestamptz;

-- Create index for unread messages
CREATE INDEX IF NOT EXISTS idx_messages_unread 
ON messages(conversation_id, read_at)
WHERE read_at IS NULL;

-- Create function to mark messages as seen
CREATE OR REPLACE FUNCTION mark_messages_seen(conversation_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Update messages read_at
  UPDATE messages
  SET read_at = now()
  WHERE conversation_id = conversation_id
  AND read_at IS NULL
  AND sender_id != auth.uid();

  -- Update participant's last_read_at
  UPDATE conversation_participants
  SET last_read_at = now()
  WHERE conversation_id = conversation_id
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
    m.read_at,
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
  LEFT JOIN message_reactions mr ON mr.message_id = m.id
  LEFT JOIN profiles mr_p ON mr_p.id = mr.user_id
  WHERE m.conversation_id = conversation_id
  AND m.created_at < before_timestamp
  GROUP BY 
    m.id, m.sender_id, m.content, m.message_type, 
    m.media_url, m.reply_to_id, m.is_unsent, 
    m.created_at, m.updated_at, m.read_at,
    p.username, p.display_name, p.avatar_url
  ORDER BY m.created_at DESC
  LIMIT limit_val;
END;
$$;