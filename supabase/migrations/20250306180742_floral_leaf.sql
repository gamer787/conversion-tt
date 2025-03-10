/*
  # Update posts table for enhanced content features

  1. Changes
    - Add new columns to posts table:
      - `additional_urls` (text[]) for carousel posts
      - `hashtags` (text[]) for hashtag tracking
      - `mentions` (text[]) for user mentions
      - `location` (text) for location tagging
      - `hide_counts` (boolean) for hiding likes/views
      - `scheduled_time` (timestamptz) for scheduled posts
      - `metadata` (jsonb) for storing editing data

  2. Security
    - Maintain existing RLS policies
*/

-- Add new columns to posts table
ALTER TABLE posts
ADD COLUMN IF NOT EXISTS additional_urls text[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS hashtags text[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS mentions text[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS location text,
ADD COLUMN IF NOT EXISTS hide_counts boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS scheduled_time timestamptz,
ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_posts_hashtags ON posts USING gin(hashtags);
CREATE INDEX IF NOT EXISTS idx_posts_mentions ON posts USING gin(mentions);
CREATE INDEX IF NOT EXISTS idx_posts_location ON posts(location);
CREATE INDEX IF NOT EXISTS idx_posts_scheduled ON posts(scheduled_time) WHERE scheduled_time IS NOT NULL;