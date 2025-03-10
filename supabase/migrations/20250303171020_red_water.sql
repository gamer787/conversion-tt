-- Drop existing functions
DROP FUNCTION IF EXISTS start_conversation CASCADE;
DROP FUNCTION IF EXISTS send_message CASCADE;
DROP FUNCTION IF EXISTS get_messages_with_info CASCADE;

-- Create function to start conversation
CREATE OR REPLACE FUNCTION start_conversation(
  participant_ids uuid[],
  title text DEFAULT NULL,
  is_group boolean DEFAULT false
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  conversation_id text;
BEGIN
  -- Validate participants
  IF NOT is_group AND array_length(participant_ids, 1) != 2 THEN
    RAISE EXCEPTION 'Direct messages must have exactly 2 participants';
  END IF;

  -- Ensure current user is in participants
  IF NOT auth.uid() = ANY(participant_ids) THEN
    RAISE EXCEPTION 'Current user must be a participant';
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
  v_conversation_exists boolean;
  v_sender_participant boolean;
  v_receiver_participant boolean;
BEGIN
  -- Check if conversation exists
  SELECT EXISTS (
    SELECT 1 FROM conversations 
    WHERE id = target_conversation_id
  ) INTO v_conversation_exists;

  IF NOT v_conversation_exists THEN
    RAISE EXCEPTION 'Conversation does not exist';
  END IF;

  -- Check if sender is participant
  SELECT EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_id = target_conversation_id
    AND user_id = auth.uid()
  ) INTO v_sender_participant;

  IF NOT v_sender_participant THEN
    RAISE EXCEPTION 'Sender is not a participant in this conversation';
  END IF;

  -- Check if receiver is participant
  SELECT EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_id = target_conversation_id
    AND user_id = target_receiver_id
  ) INTO v_receiver_participant;

  IF NOT v_receiver_participant THEN
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

-- Drop existing policies
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "messages_select_policy" ON messages;
  DROP POLICY IF EXISTS "messages_insert_policy" ON messages;
  DROP POLICY IF EXISTS "messages_update_policy" ON messages;
  DROP POLICY IF EXISTS "messages_delete_policy" ON messages;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create improved message policies
CREATE POLICY "messages_select_policy"
  ON messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM conversation_participants cp
      WHERE cp.conversation_id = messages.conversation_id
      AND cp.user_id = auth.uid()
    )
  );

CREATE POLICY "messages_insert_policy"
  ON messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM conversation_participants cp
      WHERE cp.conversation_id = messages.conversation_id
      AND cp.user_id = auth.uid()
    )
  );

CREATE POLICY "messages_update_policy"
  ON messages FOR UPDATE
  USING (sender_id = auth.uid());

CREATE POLICY "messages_delete_policy"
  ON messages FOR DELETE
  USING (sender_id = auth.uid());