/*
  # Fix Conversations Function

  1. Changes
    - Drop all existing get_conversations functions
    - Create new get_conversations_v2 function with proper parameters
    - Add proper error handling and security checks
    - Add pagination support
    - Add badge information to participants
*/

-- Drop all existing get_conversations functions
DROP FUNCTION IF EXISTS get_conversations();
DROP FUNCTION IF EXISTS get_conversations(integer, integer);

-- Create new get_conversations_v2 function with pagination
CREATE OR REPLACE FUNCTION get_conversations_v2(
  limit_val integer DEFAULT 20,
  offset_val integer DEFAULT 0
)
RETURNS TABLE (
  id text,
  title text,
  is_group boolean,
  last_message_at timestamptz,
  unread_count bigint,
  participants jsonb,
  latest_message jsonb
) 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Get current user ID
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  RETURN QUERY
  WITH user_conversations AS (
    SELECT DISTINCT c.id, c.title, c.is_group, c.last_message_at
    FROM conversations c
    JOIN conversation_participants cp ON c.id = cp.conversation_id
    WHERE cp.user_id = v_user_id
    ORDER BY c.last_message_at DESC NULLS LAST
    LIMIT limit_val
    OFFSET offset_val
  ),
  conversation_participants_info AS (
    SELECT 
      cp.conversation_id,
      jsonb_agg(
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
            AND bs.end_date >= now()
            AND bs.cancelled_at IS NULL
            LIMIT 1
          )
        )
      ) as participants
    FROM conversation_participants cp
    JOIN profiles p ON cp.user_id = p.id
    GROUP BY cp.conversation_id
  ),
  latest_messages AS (
    SELECT DISTINCT ON (m.conversation_id)
      m.conversation_id,
      jsonb_build_object(
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
            AND bs.end_date >= now()
            AND bs.cancelled_at IS NULL
            LIMIT 1
          )
        )
      ) as message_info
    FROM messages m
    JOIN profiles p ON m.sender_id = p.id
    ORDER BY m.conversation_id, m.created_at DESC
  ),
  unread_counts AS (
    SELECT 
      m.conversation_id,
      COUNT(*) as unread
    FROM messages m
    LEFT JOIN message_receipts mr ON m.id = mr.message_id AND mr.user_id = v_user_id
    WHERE mr.id IS NULL
    AND m.sender_id != v_user_id
    GROUP BY m.conversation_id
  )
  SELECT 
    uc.id,
    uc.title,
    uc.is_group,
    uc.last_message_at,
    COALESCE(un.unread, 0) as unread_count,
    COALESCE(cpi.participants, '[]'::jsonb) as participants,
    COALESCE(lm.message_info, '{}'::jsonb) as latest_message
  FROM user_conversations uc
  LEFT JOIN conversation_participants_info cpi ON uc.id = cpi.conversation_id
  LEFT JOIN latest_messages lm ON uc.id = lm.conversation_id
  LEFT JOIN unread_counts un ON uc.id = un.conversation_id
  ORDER BY uc.last_message_at DESC NULLS LAST;
END;
$$;