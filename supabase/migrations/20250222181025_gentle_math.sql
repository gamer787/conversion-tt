/*
  # Job Listings Schema

  1. New Tables
    - `job_listings`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references profiles)
      - `title` (text)
      - `company_name` (text)
      - `company_logo` (text)
      - `location` (text)
      - `type` (text) - Full-time, Part-time, Contract, etc.
      - `salary_range` (text)
      - `description` (text)
      - `requirements` (text[])
      - `benefits` (text[])
      - `status` (text) - Open, Closed, Draft
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)
      - `expires_at` (timestamptz)
      - `views` (integer)
    
    - `job_applications`
      - `id` (uuid, primary key)
      - `job_id` (uuid, references job_listings)
      - `applicant_id` (uuid, references profiles)
      - `resume_url` (text)
      - `cover_letter` (text)
      - `status` (text) - Pending, Reviewed, Accepted, Rejected
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on both tables
    - Add policies for job management and applications
*/

-- Create job listing status type
CREATE TYPE job_status AS ENUM ('open', 'closed', 'draft');

-- Create job application status type
CREATE TYPE application_status AS ENUM ('pending', 'reviewed', 'accepted', 'rejected');

-- Create job listings table
CREATE TABLE job_listings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) NOT NULL,
  title text NOT NULL,
  company_name text NOT NULL,
  company_logo text,
  location text NOT NULL,
  type text NOT NULL,
  salary_range text,
  description text NOT NULL,
  requirements text[] NOT NULL DEFAULT '{}',
  benefits text[] NOT NULL DEFAULT '{}',
  status job_status NOT NULL DEFAULT 'draft',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  views integer NOT NULL DEFAULT 0,
  CONSTRAINT valid_dates CHECK (expires_at > created_at)
);

-- Create job applications table
CREATE TABLE job_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id uuid REFERENCES job_listings(id) NOT NULL,
  applicant_id uuid REFERENCES profiles(id) NOT NULL,
  resume_url text,
  cover_letter text,
  status application_status NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(job_id, applicant_id)
);

-- Enable RLS
ALTER TABLE job_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_applications ENABLE ROW LEVEL SECURITY;

-- Create policies for job listings
CREATE POLICY "Anyone can view open jobs"
  ON job_listings FOR SELECT
  USING (status = 'open');

CREATE POLICY "Users can manage their own jobs"
  ON job_listings
  USING (user_id = auth.uid());

-- Create policies for job applications
CREATE POLICY "Users can view their own applications"
  ON job_applications FOR SELECT
  USING (applicant_id = auth.uid());

CREATE POLICY "Job owners can view applications"
  ON job_applications FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM job_listings
      WHERE id = job_applications.job_id
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create applications"
  ON job_applications FOR INSERT
  WITH CHECK (
    applicant_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM job_listings
      WHERE id = job_applications.job_id
      AND status = 'open'
    )
  );

CREATE POLICY "Users can update their own applications"
  ON job_applications FOR UPDATE
  USING (applicant_id = auth.uid());

-- Create indexes for better performance
CREATE INDEX idx_job_listings_status ON job_listings(status);
CREATE INDEX idx_job_listings_user ON job_listings(user_id);
CREATE INDEX idx_job_applications_job ON job_applications(job_id);
CREATE INDEX idx_job_applications_applicant ON job_applications(applicant_id);

-- Create function to increment job views
CREATE OR REPLACE FUNCTION increment_job_views(job_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE job_listings
  SET views = views + 1
  WHERE id = job_id
  AND status = 'open';
END;
$$;