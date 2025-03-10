-- Drop existing message policies
DROP POLICY IF EXISTS "view_messages_policy" ON messages;
DROP POLICY IF EXISTS "send_messages_policy" ON messages;

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

-- Create policy for updating messages
CREATE POLICY "messages_update_policy"
  ON messages FOR UPDATE
  USING (sender_id = auth.uid());

-- Create policy for deleting messages
CREATE POLICY "messages_delete_policy"
  ON messages FOR DELETE
  USING (sender_id = auth.uid());