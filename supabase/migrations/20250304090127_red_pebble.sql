-- Drop existing function
DROP FUNCTION IF EXISTS get_conversations;

-- Create improved function with unambiguous column references
CREATE OR REPLACE FUNCTION get_conversations(
  limit_val integer DEFAULT 20,
  offset_val integer DEFAULT 0
)
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
    WHERE m.conversation_id IN (SELECT uc.id FROM user_conversations uc)
    ORDER BY m.conversation_id, m.created_at DESC
  ),
  unread_counts AS (
    SELECT 
      m.conversation_id,
      COUNT(*) as count
    FROM messages m
    LEFT JOIN message_receipts mr ON mr.message_id = m.id
    WHERE m.conversation_id IN (SELECT uc.id FROM user_conversations uc)
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
      FROM conversation_participants cp2
      JOIN profiles p ON p.id = cp2.user_id
      WHERE cp2.conversation_id = uc.id
    ) as participants,
    cm.message as latest_message
  FROM user_conversations uc
  LEFT JOIN conversation_messages cm ON cm.conversation_id = uc.id
  LEFT JOIN unread_counts un ON un.conversation_id = uc.id;
END;
$$;