-- Drop existing function if it exists
DROP FUNCTION IF EXISTS handle_message;

-- Create function to handle message validation and creation
CREATE OR REPLACE FUNCTION handle_message(
  conversation_id text,
  receiver_id uuid,
  content text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  message_id uuid;
BEGIN
  -- Validate input
  IF content IS NULL OR trim(content) = '' THEN
    RAISE EXCEPTION 'Message content cannot be empty';
  END IF;

  IF length(content) > 5000 THEN
    RAISE EXCEPTION 'Message content cannot exceed 5000 characters';
  END IF;

  -- Validate conversation ID format
  IF NOT (
    conversation_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    AND conversation_id = LEAST(auth.uid()::text, receiver_id::text) || '_' || GREATEST(auth.uid()::text, receiver_id::text)
  ) THEN
    RAISE EXCEPTION 'Invalid conversation ID format';
  END IF;

  -- Verify receiver exists
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = receiver_id) THEN
    RAISE EXCEPTION 'Receiver does not exist';
  END IF;

  -- Verify sender can message receiver
  IF NOT EXISTS (
    -- Check for accepted friend request
    SELECT 1 FROM friend_requests
    WHERE status = 'accepted'
    AND (
      (sender_id = auth.uid() AND receiver_id = receiver_id)
      OR (receiver_id = auth.uid() AND sender_id = receiver_id)
    )
    UNION
    -- Check if receiver is a business being followed by sender
    SELECT 1 FROM follows f
    JOIN profiles p ON p.id = receiver_id
    WHERE f.follower_id = auth.uid()
    AND f.following_id = receiver_id
    AND p.account_type = 'business'
  ) THEN
    RAISE EXCEPTION 'You cannot send messages to this user';
  END IF;

  -- Insert message
  INSERT INTO messages (
    conversation_id,
    sender_id,
    receiver_id,
    content
  ) VALUES (
    conversation_id,
    auth.uid(),
    receiver_id,
    content
  )
  RETURNING id INTO message_id;

  RETURN message_id;
END;
$$;

-- Create function to mark messages as read
CREATE OR REPLACE FUNCTION mark_messages_read(conversation_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Validate conversation ID format
  IF NOT (
    conversation_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  ) THEN
    RAISE EXCEPTION 'Invalid conversation ID format';
  END IF;

  -- Mark messages as read
  UPDATE messages
  SET read_at = now()
  WHERE conversation_id = conversation_id
  AND receiver_id = auth.uid()
  AND read_at IS NULL;
END;
$$;

-- Create function to get unread message count
CREATE OR REPLACE FUNCTION get_unread_message_count(user_id uuid)
RETURNS bigint
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COUNT(*)
  FROM messages
  WHERE receiver_id = user_id
  AND read_at IS NULL;
$$;

-- Create function to get conversation messages
CREATE OR REPLACE FUNCTION get_conversation_messages(conversation_id text)
RETURNS TABLE (
  id uuid,
  sender_id uuid,
  content text,
  created_at timestamptz,
  read_at timestamptz,
  sender_name text,
  sender_username text,
  sender_avatar text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Validate conversation ID format
  IF NOT (
    conversation_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  ) THEN
    RAISE EXCEPTION 'Invalid conversation ID format';
  END IF;

  -- Verify user is part of conversation
  IF NOT (
    auth.uid()::text = split_part(conversation_id, '_', 1)
    OR auth.uid()::text = split_part(conversation_id, '_', 2)
  ) THEN
    RAISE EXCEPTION 'You are not part of this conversation';
  END IF;

  RETURN QUERY
  SELECT 
    m.id,
    m.sender_id,
    m.content,
    m.created_at,
    m.read_at,
    p.display_name as sender_name,
    p.username as sender_username,
    p.avatar_url as sender_avatar
  FROM messages m
  JOIN profiles p ON p.id = m.sender_id
  WHERE m.conversation_id = conversation_id
  ORDER BY m.created_at ASC;
END;
$$;