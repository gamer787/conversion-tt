/*
  # Sponsored Content Schema

  1. New Tables
    - `sponsored_content`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references profiles)
      - `title` (text)
      - `description` (text)
      - `content_url` (text)
      - `budget` (integer)
      - `target_audience` (text[])
      - `status` (sponsored_content_status)
      - `views` (integer)
      - `start_time` (timestamptz)
      - `end_time` (timestamptz)
      - `created_at` (timestamptz)
      - `payment_id` (uuid)

    - `sponsored_content_applications`
      - `id` (uuid, primary key)
      - `content_id` (uuid, references sponsored_content)
      - `applicant_id` (uuid, references profiles)
      - `status` (application_status)
      - `portfolio_url` (text)
      - `cover_letter` (text)
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS on all tables
    - Add policies for content creation and viewing
    - Add policies for application management

  3. Functions
    - Add function to check creator eligibility
    - Add function to submit applications
    - Add function to manage content status
*/

-- Create sponsored content status enum
CREATE TYPE sponsored_content_status AS ENUM ('draft', 'pending', 'active', 'completed', 'cancelled');

-- Create sponsored content table
CREATE TABLE IF NOT EXISTS sponsored_content (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id),
  title text NOT NULL,
  description text NOT NULL,
  content_url text NOT NULL,
  budget integer NOT NULL CHECK (budget > 0),
  target_audience text[] DEFAULT '{}',
  status sponsored_content_status DEFAULT 'draft',
  views integer DEFAULT 0,
  start_time timestamptz,
  end_time timestamptz,
  created_at timestamptz DEFAULT now(),
  payment_id uuid REFERENCES payments(id),
  CONSTRAINT valid_dates CHECK (end_time > start_time)
);

-- Create sponsored content applications table
CREATE TABLE IF NOT EXISTS sponsored_content_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_id uuid NOT NULL REFERENCES sponsored_content(id) ON DELETE CASCADE,
  applicant_id uuid NOT NULL REFERENCES profiles(id),
  status application_status DEFAULT 'pending',
  portfolio_url text,
  cover_letter text,
  created_at timestamptz DEFAULT now(),
  UNIQUE(content_id, applicant_id)
);

-- Enable RLS
ALTER TABLE sponsored_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE sponsored_content_applications ENABLE ROW LEVEL SECURITY;

-- Policies for sponsored content
CREATE POLICY "Business users can create sponsored content"
  ON sponsored_content
  FOR INSERT
  TO public
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND account_type = 'business'
    )
  );

CREATE POLICY "Users can view active sponsored content"
  ON sponsored_content
  FOR SELECT
  TO public
  USING (
    status = 'active'
    OR user_id = auth.uid()
  );

CREATE POLICY "Business users can update own content"
  ON sponsored_content
  FOR UPDATE
  TO public
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Policies for applications
CREATE POLICY "Eligible users can apply"
  ON sponsored_content_applications
  FOR INSERT
  TO public
  WITH CHECK (
    applicant_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND EXISTS (
        SELECT 1
        FROM friend_requests fr
        WHERE fr.status = 'accepted'
        AND (fr.sender_id = p.id OR fr.receiver_id = p.id)
        GROUP BY p.id
        HAVING count(*) >= 2000
      )
      AND EXISTS (
        SELECT 1
        FROM posts
        WHERE user_id = p.id
        AND type = 'banger'
        GROUP BY user_id
        HAVING count(*) >= 45
      )
      AND EXISTS (
        SELECT 1
        FROM posts
        WHERE user_id = p.id
        AND type = 'vibe'
        GROUP BY user_id
        HAVING count(*) >= 30
      )
      AND EXISTS (
        SELECT 1
        FROM follows f
        JOIN profiles bp ON bp.id = f.following_id
        WHERE f.follower_id = p.id
        AND bp.account_type = 'business'
        GROUP BY f.follower_id
        HAVING count(*) >= 15
      )
      AND (EXTRACT(EPOCH FROM now() - p.created_at) / 86400) >= 90
      AND EXISTS (
        SELECT 1
        FROM posts
        WHERE user_id = p.id
        AND created_at >= now() - interval '30 days'
      )
    )
  );

CREATE POLICY "Users can view own applications"
  ON sponsored_content_applications
  FOR SELECT
  TO public
  USING (
    applicant_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM sponsored_content
      WHERE id = content_id
      AND user_id = auth.uid()
    )
  );

-- Create function to check creator eligibility
CREATE OR REPLACE FUNCTION check_creator_eligibility(user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM profiles p
    WHERE p.id = user_id
    -- Must have 2000+ accepted friend requests
    AND EXISTS (
      SELECT 1
      FROM friend_requests fr
      WHERE fr.status = 'accepted'
      AND (fr.sender_id = p.id OR fr.receiver_id = p.id)
      GROUP BY p.id
      HAVING count(*) >= 2000
    )
    -- Must have 45+ bangers
    AND EXISTS (
      SELECT 1
      FROM posts
      WHERE user_id = p.id
      AND type = 'banger'
      GROUP BY user_id
      HAVING count(*) >= 45
    )
    -- Must have 30+ vibes
    AND EXISTS (
      SELECT 1
      FROM posts
      WHERE user_id = p.id
      AND type = 'vibe'
      GROUP BY user_id
      HAVING count(*) >= 30
    )
    -- Must follow 15+ business accounts
    AND EXISTS (
      SELECT 1
      FROM follows f
      JOIN profiles bp ON bp.id = f.following_id
      WHERE f.follower_id = p.id
      AND bp.account_type = 'business'
      GROUP BY f.follower_id
      HAVING count(*) >= 15
    )
    -- Account must be 90+ days old
    AND (EXTRACT(EPOCH FROM now() - p.created_at) / 86400) >= 90
    -- Must have posted in last 30 days
    AND EXISTS (
      SELECT 1
      FROM posts
      WHERE user_id = p.id
      AND created_at >= now() - interval '30 days'
    )
  );
END;
$$;