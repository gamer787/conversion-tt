/*
  # Add friend requests and discovered users functionality

  1. New Tables
    - `friend_requests`
      - `id` (uuid, primary key)
      - `sender_id` (uuid, references profiles)
      - `receiver_id` (uuid, references profiles)
      - `status` (enum: pending, accepted, rejected)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
    
    - `discovered_users`
      - `id` (uuid, primary key)
      - `discoverer_id` (uuid, references profiles)
      - `discovered_id` (uuid, references profiles)
      - `bluetooth_id` (text)
      - `last_seen` (timestamp)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on both tables
    - Add policies for managing friend requests and discovered users
*/

-- Drop existing tables and types if they exist
DROP TABLE IF EXISTS friend_requests;
DROP TABLE IF EXISTS discovered_users;
DROP TYPE IF EXISTS friend_request_status;

-- Create friend request status enum
CREATE TYPE friend_request_status AS ENUM ('pending', 'accepted', 'rejected');

-- Create friend requests table
CREATE TABLE friend_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid REFERENCES profiles(id) NOT NULL,
  receiver_id uuid REFERENCES profiles(id) NOT NULL,
  status friend_request_status NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(sender_id, receiver_id)
);

-- Create discovered users table
CREATE TABLE discovered_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  discoverer_id uuid REFERENCES profiles(id) NOT NULL,
  discovered_id uuid REFERENCES profiles(id) NOT NULL,
  bluetooth_id text NOT NULL,
  last_seen timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(discoverer_id, discovered_id)
);

-- Enable RLS
ALTER TABLE friend_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE discovered_users ENABLE ROW LEVEL SECURITY;

-- Friend requests policies
CREATE POLICY "friend_requests_select_policy"
  ON friend_requests FOR SELECT
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "friend_requests_insert_policy"
  ON friend_requests FOR INSERT
  WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "friend_requests_update_policy"
  ON friend_requests FOR UPDATE
  USING (auth.uid() = receiver_id);

-- Discovered users policies
CREATE POLICY "discovered_users_select_policy"
  ON discovered_users FOR SELECT
  USING (auth.uid() = discoverer_id);

CREATE POLICY "discovered_users_insert_policy"
  ON discovered_users FOR INSERT
  WITH CHECK (auth.uid() = discoverer_id);

CREATE POLICY "discovered_users_update_policy"
  ON discovered_users FOR UPDATE
  USING (auth.uid() = discoverer_id);

-- Indexes for better performance
CREATE INDEX idx_friend_requests_sender ON friend_requests(sender_id);
CREATE INDEX idx_friend_requests_receiver ON friend_requests(receiver_id);
CREATE INDEX idx_friend_requests_status ON friend_requests(status);
CREATE INDEX idx_discovered_users_discoverer ON discovered_users(discoverer_id);
CREATE INDEX idx_discovered_users_discovered ON discovered_users(discovered_id);
CREATE INDEX idx_discovered_users_bluetooth ON discovered_users(bluetooth_id);
CREATE INDEX idx_discovered_users_last_seen ON discovered_users(last_seen);