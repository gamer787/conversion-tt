/*
  # Content Drafts Schema

  1. New Tables
    - `content_drafts`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references profiles)
      - `content` (jsonb)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS
    - Add policies for CRUD operations
    - Users can only access their own drafts

  3. Indexes
    - Index on user_id for faster lookups
    - Index on updated_at for sorting drafts
*/

-- Create content drafts table if it doesn't exist
CREATE TABLE IF NOT EXISTS content_drafts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content jsonb NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE content_drafts ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$ 
BEGIN
  -- Drop policies if they exist
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'content_drafts' 
    AND policyname = 'Users can create their own drafts'
  ) THEN
    DROP POLICY "Users can create their own drafts" ON content_drafts;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'content_drafts' 
    AND policyname = 'Users can view their own drafts'
  ) THEN
    DROP POLICY "Users can view their own drafts" ON content_drafts;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'content_drafts' 
    AND policyname = 'Users can update their own drafts'
  ) THEN
    DROP POLICY "Users can update their own drafts" ON content_drafts;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'content_drafts' 
    AND policyname = 'Users can delete their own drafts'
  ) THEN
    DROP POLICY "Users can delete their own drafts" ON content_drafts;
  END IF;
END $$;

-- Create policies
CREATE POLICY "Users can create their own drafts"
  ON content_drafts
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own drafts"
  ON content_drafts
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own drafts"
  ON content_drafts
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own drafts"
  ON content_drafts
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Drop existing indexes if they exist
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE tablename = 'content_drafts' 
    AND indexname = 'idx_content_drafts_user'
  ) THEN
    DROP INDEX idx_content_drafts_user;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE tablename = 'content_drafts' 
    AND indexname = 'idx_content_drafts_updated'
  ) THEN
    DROP INDEX idx_content_drafts_updated;
  END IF;
END $$;

-- Create indexes
CREATE INDEX idx_content_drafts_user ON content_drafts(user_id);
CREATE INDEX idx_content_drafts_updated ON content_drafts(updated_at DESC);

-- Drop existing trigger if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'update_content_drafts_updated_at'
  ) THEN
    DROP TRIGGER update_content_drafts_updated_at ON content_drafts;
  END IF;
END $$;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS update_content_drafts_updated_at();

-- Create function and trigger for updated_at
CREATE OR REPLACE FUNCTION update_content_drafts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_content_drafts_updated_at
  BEFORE UPDATE ON content_drafts
  FOR EACH ROW
  EXECUTE FUNCTION update_content_drafts_updated_at();