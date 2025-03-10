/*
  # Fix Storage Bucket Policies

  1. Changes
    - Create storage buckets with proper configuration
    - Set up RLS policies with correct order
    - Ensure proper bucket initialization

  2. Security
    - Maintain proper access control
    - Enable uploads for authenticated users
    - Restrict content access appropriately
*/

-- Enable storage extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create avatars bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Create vibes bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('vibes', 'vibes', true)
ON CONFLICT (id) DO NOTHING;

-- Create bangers bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('bangers', 'bangers', true)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies to ensure clean slate
DROP POLICY IF EXISTS "avatars_policy" ON storage.objects;
DROP POLICY IF EXISTS "vibes_policy" ON storage.objects;
DROP POLICY IF EXISTS "bangers_policy" ON storage.objects;

-- Create unified policies for all buckets
CREATE POLICY "storage_policy" ON storage.objects
FOR ALL USING (
  CASE
    -- Avatars bucket
    WHEN bucket_id = 'avatars' THEN
      auth.uid()::text = SPLIT_PART(name, '/', 1)
    
    -- Vibes bucket
    WHEN bucket_id = 'vibes' THEN
      -- Allow insert/delete for own content
      (
        (array['INSERT', 'DELETE']::text[] @> ARRAY[current_setting('storage.object_action')])
        AND auth.uid()::text = SPLIT_PART(name, '/', 1)
      )
      -- Allow select based on relationships
      OR (
        current_setting('storage.object_action') = 'SELECT'
        AND (
          auth.uid()::text = SPLIT_PART(name, '/', 1)
          OR EXISTS (
            SELECT 1 FROM friend_requests
            WHERE status = 'accepted'
            AND (
              (sender_id = auth.uid() AND receiver_id::text = SPLIT_PART(name, '/', 1))
              OR (receiver_id = auth.uid() AND sender_id::text = SPLIT_PART(name, '/', 1))
            )
          )
          OR EXISTS (
            SELECT 1 FROM follows f
            JOIN profiles p ON p.id::text = SPLIT_PART(name, '/', 1)
            WHERE f.follower_id = auth.uid()
            AND f.following_id::text = SPLIT_PART(name, '/', 1)
            AND p.account_type = 'business'
          )
        )
      )
    
    -- Bangers bucket
    WHEN bucket_id = 'bangers' THEN
      -- Allow insert/delete for own content
      (
        (array['INSERT', 'DELETE']::text[] @> ARRAY[current_setting('storage.object_action')])
        AND auth.uid()::text = SPLIT_PART(name, '/', 1)
      )
      -- Allow select based on relationships
      OR (
        current_setting('storage.object_action') = 'SELECT'
        AND (
          auth.uid()::text = SPLIT_PART(name, '/', 1)
          OR EXISTS (
            SELECT 1 FROM friend_requests
            WHERE status = 'accepted'
            AND (
              (sender_id = auth.uid() AND receiver_id::text = SPLIT_PART(name, '/', 1))
              OR (receiver_id = auth.uid() AND sender_id::text = SPLIT_PART(name, '/', 1))
            )
          )
          OR EXISTS (
            SELECT 1 FROM follows f
            JOIN profiles p ON p.id::text = SPLIT_PART(name, '/', 1)
            WHERE f.follower_id = auth.uid()
            AND f.following_id::text = SPLIT_PART(name, '/', 1)
            AND p.account_type = 'business'
          )
        )
      )
    
    ELSE false
  END
);