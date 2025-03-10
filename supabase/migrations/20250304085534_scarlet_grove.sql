-- Drop existing functions first
DROP FUNCTION IF EXISTS get_conversations(integer,integer);
DROP FUNCTION IF EXISTS mark_messages_seen(text);
DROP FUNCTION IF EXISTS update_typing_status(text,boolean);
DROP FUNCTION IF EXISTS add_reaction(uuid,text);
DROP FUNCTION IF EXISTS remove_reaction(uuid);

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

-- Create function to update typing status
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

-- Create function to add reaction
CREATE OR REPLACE FUNCTION add_reaction(
  target_message_id uuid,
  reaction_text text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO message_reactions (message_id, user_id, reaction)
  VALUES (target_message_id, auth.uid(), reaction_text)
  ON CONFLICT (message_id, user_id)
  DO UPDATE SET 
    reaction = reaction_text,
    created_at = now();
END;
$$;

-- Create function to remove reaction
CREATE OR REPLACE FUNCTION remove_reaction(target_message_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM message_reactions
  WHERE message_id = target_message_id
  AND user_id = auth.uid();
END;
$$;

-- Create function to get conversations with latest messages
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