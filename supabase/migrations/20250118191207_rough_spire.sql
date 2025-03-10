/*
  # Add Friend Requests System

  1. New Types
    - `friend_request_status` enum for request states

  2. New Tables
    - `friend_requests` for tracking friend requests between users
    - `discovered_users` for storing users found via Bluetooth

  3. Security
    - Enable RLS on new tables
    - Add policies for proper access control
*/

-- Create friend request status enum
CREATE TYPE friend_request_status AS ENUM ('pending', 'accepted', 'rejected');

-- Create friend requests table
CREATE TABLE IF NOT EXISTS friend_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid REFERENCES profiles(id) NOT NULL,
  receiver_id uuid REFERENCES profiles(id) NOT NULL,
  status friend_request_status NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(sender_id, receiver_id)
);

-- Create discovered users table for Bluetooth discoveries
CREATE TABLE IF NOT EXISTS discovered_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  discoverer_id uuid REFERENCES profiles(id) NOT NULL,
  discovered_id uuid REFERENCES profiles(id) NOT NULL,
  last_seen timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(discoverer_id, discovered_id)
);

-- Enable RLS
ALTER TABLE friend_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE discovered_users ENABLE ROW LEVEL SECURITY;

-- Friend requests policies
CREATE POLICY "Users can view their own requests"
  ON friend_requests FOR SELECT
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can send friend requests"
  ON friend_requests FOR INSERT
  WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can update their received requests"
  ON friend_requests FOR UPDATE
  USING (auth.uid() = receiver_id);

-- Discovered users policies
CREATE POLICY "Users can view their discoveries"
  ON discovered_users FOR SELECT
  USING (auth.uid() = discoverer_id);

CREATE POLICY "Users can add discoveries"
  ON discovered_users FOR INSERT
  WITH CHECK (auth.uid() = discoverer_id);

CREATE POLICY "Users can update their discoveries"
  ON discovered_users FOR UPDATE
  USING (auth.uid() = discoverer_id);

-- Add indexes for better performance
CREATE INDEX idx_friend_requests_sender ON friend_requests(sender_id);
CREATE INDEX idx_friend_requests_receiver ON friend_requests(receiver_id);
CREATE INDEX idx_friend_requests_status ON friend_requests(status);
CREATE INDEX idx_discovered_users_discoverer ON discovered_users(discoverer_id);
CREATE INDEX idx_discovered_users_last_seen ON discovered_users(last_seen);

-- Function to handle friend request responses
CREATE OR REPLACE FUNCTION handle_friend_request_response()
RETURNS TRIGGER AS $$
BEGIN
  -- Update the updated_at timestamp
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for friend request responses
CREATE TRIGGER friend_request_response_trigger
  BEFORE UPDATE ON friend_requests
  FOR EACH ROW
  EXECUTE FUNCTION handle_friend_request_response();