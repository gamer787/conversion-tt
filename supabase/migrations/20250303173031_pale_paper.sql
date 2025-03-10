-- Drop messaging-related tables in the correct order
DROP TABLE IF EXISTS typing_status CASCADE;
DROP TABLE IF EXISTS message_reactions CASCADE;
DROP TABLE IF EXISTS message_receipts CASCADE;
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS conversation_participants CASCADE;
DROP TABLE IF EXISTS conversations CASCADE;

-- Drop messaging-related types
DROP TYPE IF EXISTS message_type CASCADE;
DROP TYPE IF EXISTS message_status CASCADE;

-- Drop messaging-related functions
DROP FUNCTION IF EXISTS start_conversation CASCADE;
DROP FUNCTION IF EXISTS send_message CASCADE;
DROP FUNCTION IF EXISTS mark_messages_seen CASCADE;
DROP FUNCTION IF EXISTS get_messages_with_info CASCADE;
DROP FUNCTION IF EXISTS get_conversation_messages CASCADE;
DROP FUNCTION IF EXISTS update_typing_status CASCADE;
DROP FUNCTION IF EXISTS unsend_message CASCADE;
DROP FUNCTION IF EXISTS add_reaction CASCADE;
DROP FUNCTION IF EXISTS remove_reaction CASCADE;

-- Drop storage bucket for message media if it exists
DO $$ 
BEGIN
  DELETE FROM storage.buckets
  WHERE id IN ('message-images', 'message-videos');
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END $$;