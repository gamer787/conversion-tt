-- Drop existing objects in the correct order
DROP TABLE IF EXISTS typing_status CASCADE;
DROP TABLE IF EXISTS message_reactions CASCADE;
DROP TABLE IF EXISTS message_receipts CASCADE;
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS conversation_participants CASCADE;
DROP TABLE IF EXISTS conversations CASCADE;
DROP TYPE IF EXISTS message_type CASCADE;
DROP TYPE IF EXISTS message_status CASCADE;

-- Create message types enum
CREATE TYPE message_type AS ENUM (
  'text',
  'image',
  'video',
  'voice',
  'gif',
  'sticker'
);

-- Create message status enum
CREATE TYPE message_status AS ENUM (
  'sent',
  'delivered',
  'seen'
);

-- Create conversations table with text ID
CREATE TABLE conversations (
  id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  title text,
  is_group boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  last_message_at timestamptz,
  encryption_key text
);

-- Create conversation participants table
CREATE TABLE conversation_participants (
  conversation_id text REFERENCES conversations(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(),
  last_read_at timestamptz,
  is_admin boolean NOT NULL DEFAULT false,
  PRIMARY KEY (conversation_id, user_id)
);

-- Create messages table
CREATE TABLE messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id text REFERENCES conversations(id) ON DELETE CASCADE NOT NULL,
  sender_id uuid REFERENCES profiles(id) ON DELETE SET NULL NOT NULL,
  receiver_id uuid REFERENCES profiles(id),
  message_type message_type NOT NULL DEFAULT 'text',
  content text,
  media_url text,
  reply_to_id uuid REFERENCES messages(id),
  is_unsent boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  read_at timestamptz
);

-- Create message reactions table
CREATE TABLE message_reactions (
  message_id uuid REFERENCES messages(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  reaction text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);

-- Create message receipts table
CREATE TABLE message_receipts (
  message_id uuid REFERENCES messages(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  status message_status NOT NULL DEFAULT 'sent',
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);

-- Create typing status table
CREATE TABLE typing_status (
  conversation_id text REFERENCES conversations(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  started_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (conversation_id, user_id)
);

-- Enable RLS
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE typing_status ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "view_conversations_policy_new"
  ON conversations FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM conversation_participants
      WHERE conversation_id = id
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "create_conversations_policy"
  ON conversations FOR INSERT
  WITH CHECK (true);

CREATE POLICY "view_participants_policy"
  ON conversation_participants FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "view_messages_policy"
  ON messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM conversation_participants
      WHERE conversation_id = messages.conversation_id
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "send_messages_policy"
  ON messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM conversation_participants
      WHERE conversation_id = messages.conversation_id
      AND user_id = auth.uid()
    )
  );

-- Create indexes
CREATE INDEX idx_conversation_participants_user 
ON conversation_participants(user_id);

CREATE INDEX idx_messages_conversation 
ON messages(conversation_id);

CREATE INDEX idx_messages_sender 
ON messages(sender_id);

CREATE INDEX idx_messages_receiver 
ON messages(receiver_id);

CREATE INDEX idx_messages_reply 
ON messages(reply_to_id) 
WHERE reply_to_id IS NOT NULL;

CREATE INDEX idx_message_reactions_message 
ON message_reactions(message_id);

CREATE INDEX idx_message_receipts_message 
ON message_receipts(message_id);

CREATE INDEX idx_typing_status_conversation 
ON typing_status(conversation_id);