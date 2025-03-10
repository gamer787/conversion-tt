/*
  # Remove Messaging Feature

  1. Changes
    - Drop all messaging-related tables
    - Drop messaging-related functions
    - Remove messaging-related triggers
    - Clean up any messaging-related data

  2. Tables to Remove
    - messages
    - message_reactions
    - message_receipts
    - typing_status
    - conversations
    - conversation_participants
*/

-- Drop messaging-related functions first
DROP FUNCTION IF EXISTS get_messages_with_info(target_conversation_id text);
DROP FUNCTION IF EXISTS get_conversations_v3(integer, integer);
DROP FUNCTION IF EXISTS send_message(target_conversation_id text, target_receiver_id uuid, content text);
DROP FUNCTION IF EXISTS mark_messages_seen(target_conversation_id text);
DROP FUNCTION IF EXISTS update_typing_status(target_conversation_id text, is_typing boolean);

-- Drop messaging-related tables
DROP TABLE IF EXISTS message_reactions CASCADE;
DROP TABLE IF EXISTS message_receipts CASCADE;
DROP TABLE IF EXISTS typing_status CASCADE;
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS conversation_participants CASCADE;
DROP TABLE IF EXISTS conversations CASCADE;