/*
  # Fix get_conversations_v3 function

  1. Changes
    - Remove function overloading by consolidating into a single function
    - Add pagination parameters with default values
    - Fix return type structure
    - Add proper participant info and latest message details

  2. Return Structure
    - id: text
    - title: text
    - is_group: boolean
    - last_message_at: timestamptz
    - unread_count: bigint
    - participants: jsonb[]
    - latest_message: jsonb
*/

-- Drop existing functions to avoid conflicts
DROP FUNCTION IF EXISTS get_conversations_v3();
DROP FUNCTION IF EXISTS get_conversations_v3(integer, integer);

CREATE OR REPLACE FUNCTION get_conversations_v3(
  limit_val integer DEFAULT 20,
  offset_val integer DEFAULT 0
)
RETURNS TABLE (
  id text,
  title text,
  is_group boolean,
  last_message_at timestamptz,
  unread_count bigint,
  participants jsonb[],
  latest_message jsonb
) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH user_conversations AS (
    -- Get conversations the current user is part of
    SELECT DISTINCT c.id, c.title, c.is_group, c.last_message_at
    FROM conversations c
    JOIN conversation_participants cp ON c.id = cp.conversation_id
    WHERE cp.user_id = auth.uid()
  ),
  conversation_participants AS (
    -- Get participant info for each conversation
    SELECT 
      cp.conversation_id,
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
      ) as participant_info
    FROM conversation_participants cp
    JOIN profiles p ON cp.user_id = p.id
    WHERE cp.conversation_id IN (SELECT id FROM user_conversations)
      AND cp.user_id != auth.uid()
  ),
  latest_messages AS (
    -- Get latest message for each conversation
    SELECT DISTINCT ON (m.conversation_id)
      m.conversation_id,
      jsonb_build_object(
        'id', m.id,
        'content', m.content,
        'message_type', m.message_type,
        'media_url', m.media_url,
        'created_at', m.created_at,
        'is_unsent', m.is_unsent,
        'read_at', m.read_at,
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
      ) as message_info
    FROM messages m
    JOIN profiles p ON m.sender_id = p.id
    WHERE m.conversation_id IN (SELECT id FROM user_conversations)
    ORDER BY m.conversation_id, m.created_at DESC
  ),
  unread_counts AS (
    -- Get unread message count for each conversation
    SELECT 
      m.conversation_id,
      COUNT(*) as unread_count
    FROM messages m
    WHERE m.conversation_id IN (SELECT id FROM user_conversations)
      AND m.sender_id != auth.uid()
      AND m.read_at IS NULL
    GROUP BY m.conversation_id
  )
  SELECT 
    uc.id,
    uc.title,
    uc.is_group,
    uc.last_message_at,
    COALESCE(un.unread_count, 0) as unread_count,
    array_agg(cp.participant_info) as participants,
    lm.message_info as latest_message
  FROM user_conversations uc
  LEFT JOIN conversation_participants cp ON uc.id = cp.conversation_id
  LEFT JOIN latest_messages lm ON uc.id = lm.conversation_id
  LEFT JOIN unread_counts un ON uc.id = un.conversation_id
  GROUP BY 
    uc.id,
    uc.title,
    uc.is_group,
    uc.last_message_at,
    un.unread_count,
    lm.message_info
  ORDER BY uc.last_message_at DESC NULLS LAST
  LIMIT limit_val
  OFFSET offset_val;
END;
$$;

-- Update function permissions
REVOKE EXECUTE ON FUNCTION get_conversations_v3(integer, integer) FROM public;
GRANT EXECUTE ON FUNCTION get_conversations_v3(integer, integer) TO authenticated;