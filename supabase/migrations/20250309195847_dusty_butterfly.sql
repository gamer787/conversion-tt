/*
  # Add conversation functions
  
  1. New Functions
    - get_conversations: Returns user's conversations with latest messages
    - get_messages_with_info: Returns messages with sender info for a conversation
    - mark_messages_seen: Marks messages as seen in a conversation
    - update_typing_status: Updates user's typing status in a conversation
    - send_message: Sends a new message in a conversation

  2. Changes
    - Added proper error handling
    - Added input validation
    - Added security checks
*/

-- Function to get user's conversations with latest messages
CREATE OR REPLACE FUNCTION get_conversations()
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
  ),
  conversation_participants_info AS (
    SELECT 
      cp.conversation_id,
      jsonb_agg(
        jsonb_build_object(
          'user_id', p.id,
          'username', p.username,
          'display_name', p.display_name,
          'avatar_url', p.avatar_url
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
          'avatar_url', p.avatar_url
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

-- Function to get messages with sender info
CREATE OR REPLACE FUNCTION get_messages_with_info(target_conversation_id text)
RETURNS TABLE (
  id uuid,
  sender_id uuid,
  content text,
  message_type message_type,
  media_url text,
  reply_to_id uuid,
  created_at timestamptz,
  is_unsent boolean,
  read_at timestamptz,
  sender_info jsonb,
  reactions jsonb
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

  -- Check if user is participant
  IF NOT EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_id = target_conversation_id
    AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Not a participant in this conversation';
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
    m.is_unsent,
    mr.updated_at as read_at,
    jsonb_build_object(
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
    ) as sender_info,
    COALESCE(
      jsonb_object_agg(
        mr2.reaction,
        jsonb_build_object(
          'count', COUNT(*),
          'users', jsonb_agg(
            jsonb_build_object(
              'user_id', p2.id,
              'username', p2.username
            )
          )
        )
      ) FILTER (WHERE mr2.reaction IS NOT NULL),
      '{}'::jsonb
    ) as reactions
  FROM messages m
  JOIN profiles p ON m.sender_id = p.id
  LEFT JOIN message_receipts mr ON m.id = mr.message_id AND mr.user_id = v_user_id
  LEFT JOIN message_reactions mr2 ON m.id = mr2.message_id
  LEFT JOIN profiles p2 ON mr2.user_id = p2.id
  WHERE m.conversation_id = target_conversation_id
  GROUP BY m.id, m.sender_id, m.content, m.message_type, m.media_url, 
           m.reply_to_id, m.created_at, m.is_unsent, mr.updated_at,
           p.username, p.display_name, p.avatar_url
  ORDER BY m.created_at ASC;
END;
$$;

-- Function to mark messages as seen
CREATE OR REPLACE FUNCTION mark_messages_seen(target_conversation_id text)
RETURNS void
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

  -- Check if user is participant
  IF NOT EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_id = target_conversation_id
    AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Not a participant in this conversation';
  END IF;

  -- Mark messages as seen
  INSERT INTO message_receipts (message_id, user_id, status)
  SELECT m.id, v_user_id, 'seen'
  FROM messages m
  LEFT JOIN message_receipts mr ON m.id = mr.message_id AND mr.user_id = v_user_id
  WHERE m.conversation_id = target_conversation_id
  AND m.sender_id != v_user_id
  AND mr.id IS NULL
  ON CONFLICT (message_id, user_id) DO UPDATE
  SET status = 'seen', updated_at = now();
END;
$$;

-- Function to update typing status
CREATE OR REPLACE FUNCTION update_typing_status(
  target_conversation_id text,
  is_typing boolean
)
RETURNS void
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

  -- Check if user is participant
  IF NOT EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_id = target_conversation_id
    AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Not a participant in this conversation';
  END IF;

  IF is_typing THEN
    -- Insert or update typing status
    INSERT INTO typing_status (conversation_id, user_id, started_at)
    VALUES (target_conversation_id, v_user_id, now())
    ON CONFLICT (conversation_id, user_id) 
    DO UPDATE SET started_at = now();
  ELSE
    -- Remove typing status
    DELETE FROM typing_status
    WHERE conversation_id = target_conversation_id
    AND user_id = v_user_id;
  END IF;
END;
$$;

-- Function to send a message
CREATE OR REPLACE FUNCTION send_message(
  target_conversation_id text,
  target_receiver_id uuid,
  content text,
  message_type message_type DEFAULT 'text',
  media_url text DEFAULT NULL,
  reply_to_id uuid DEFAULT NULL
)
RETURNS uuid
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id uuid;
  v_message_id uuid;
BEGIN
  -- Get current user ID
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Validate input
  IF content IS NULL AND media_url IS NULL THEN
    RAISE EXCEPTION 'Message must have either content or media';
  END IF;

  -- Check if conversation exists or create new one
  IF target_conversation_id IS NULL THEN
    IF target_receiver_id IS NULL THEN
      RAISE EXCEPTION 'Must provide either conversation_id or receiver_id';
    END IF;

    -- Create new conversation
    INSERT INTO conversations (is_group)
    VALUES (false)
    RETURNING id INTO target_conversation_id;

    -- Add participants
    INSERT INTO conversation_participants (conversation_id, user_id)
    VALUES 
      (target_conversation_id, v_user_id),
      (target_conversation_id, target_receiver_id);
  ELSE
    -- Check if user is participant
    IF NOT EXISTS (
      SELECT 1 FROM conversation_participants
      WHERE conversation_id = target_conversation_id
      AND user_id = v_user_id
    ) THEN
      RAISE EXCEPTION 'Not a participant in this conversation';
    END IF;
  END IF;

  -- Send message
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
    v_user_id,
    target_receiver_id,
    content,
    message_type,
    media_url,
    reply_to_id
  )
  RETURNING id INTO v_message_id;

  -- Update conversation last_message_at
  UPDATE conversations
  SET last_message_at = now()
  WHERE id = target_conversation_id;

  RETURN v_message_id;
END;
$$;