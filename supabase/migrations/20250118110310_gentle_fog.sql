/*
  # User Profiles and Interactions Schema

  1. New Tables
    - `profiles`
      - Personal and business user profiles
      - Stores user details, account type, verification status
    - `follows`
      - Tracks connections between users
    - `posts`
      - Stores vibes and bangers content
    - `interactions`
      - Stores likes and comments on posts
    
  2. Security
    - Enable RLS on all tables
    - Policies for authenticated users
    - Public read access for verified profiles
*/

-- Create enum for account types
CREATE TYPE account_type AS ENUM ('personal', 'business');

-- Create enum for post types
CREATE TYPE post_type AS ENUM ('vibe', 'banger');

-- Profiles table
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id),
  username text UNIQUE NOT NULL,
  display_name text NOT NULL,
  bio text,
  avatar_url text,
  account_type account_type NOT NULL DEFAULT 'personal',
  is_verified boolean NOT NULL DEFAULT false,
  location text,
  website text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Follows table for user connections
CREATE TABLE IF NOT EXISTS follows (
  follower_id uuid REFERENCES profiles(id),
  following_id uuid REFERENCES profiles(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, following_id)
);

-- Posts table for vibes and bangers
CREATE TABLE IF NOT EXISTS posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) NOT NULL,
  type post_type NOT NULL,
  content_url text NOT NULL,
  caption text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Interactions table for likes and comments
CREATE TABLE IF NOT EXISTS interactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) NOT NULL,
  post_id uuid REFERENCES posts(id) NOT NULL,
  type text NOT NULL CHECK (type IN ('like', 'comment')),
  comment_text text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE interactions ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Public profiles are viewable by everyone"
  ON profiles FOR SELECT
  USING (true);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- Follows policies
CREATE POLICY "Anyone can read follows"
  ON follows FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can follow others"
  ON follows FOR INSERT
  WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Users can unfollow"
  ON follows FOR DELETE
  USING (auth.uid() = follower_id);

-- Posts policies
CREATE POLICY "Posts are viewable by everyone"
  ON posts FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can create posts"
  ON posts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own posts"
  ON posts FOR DELETE
  USING (auth.uid() = user_id);

-- Interactions policies
CREATE POLICY "Interactions are viewable by everyone"
  ON interactions FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can interact"
  ON interactions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own interactions"
  ON interactions FOR DELETE
  USING (auth.uid() = user_id);

-- Functions
CREATE OR REPLACE FUNCTION get_profile_stats(profile_id uuid)
RETURNS TABLE (
  followers_count bigint,
  following_count bigint,
  posts_count bigint
) LANGUAGE sql STABLE AS $$
  SELECT
    (SELECT count(*) FROM follows WHERE following_id = profile_id) as followers_count,
    (SELECT count(*) FROM follows WHERE follower_id = profile_id) as following_count,
    (SELECT count(*) FROM posts WHERE user_id = profile_id) as posts_count;
$$;