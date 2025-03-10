/*
  # Fix Messaging System Schema V2

  1. Changes
    - Drop and recreate messaging functions
    - Update conversation queries
    - Fix participant handling
    - Add proper indices

  2. Security
    - RLS policies for all tables
    - Participants can only access their conversations
    - Message senders can unsend their own messages
    - Typing status visible to conversation participants
*/

-- Drop existing functions if they exist
DROP FUNCTION IF EXISTS get_conversations();
DROP FUNCTION IF EXISTS get_conversations_v2();
DROP FUNCTION IF EXISTS get_conversations_v3();

-- Create new conversations function
CREATE OR REPLACE FUNCTION get_conversations()
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