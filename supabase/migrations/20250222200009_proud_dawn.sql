-- Drop existing objects in the correct order
DROP FUNCTION IF EXISTS update_application_status CASCADE;
DROP FUNCTION IF EXISTS get_job_applications CASCADE;
DROP TABLE IF EXISTS job_applications CASCADE;
DROP TYPE IF EXISTS application_status CASCADE;

-- Create application status enum with on_hold
CREATE TYPE application_status AS ENUM ('unviewed', 'pending', 'on_hold', 'accepted', 'rejected');

-- Create job applications table
CREATE TABLE job_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id uuid REFERENCES job_listings(id) NOT NULL,
  applicant_id uuid REFERENCES profiles(id) NOT NULL,
  resume_url text,
  cover_letter text,
  status application_status NOT NULL DEFAULT 'unviewed',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(job_id, applicant_id)
);

-- Create function to get applications with badges
CREATE OR REPLACE FUNCTION get_job_applications(job_id uuid)
RETURNS TABLE (
  id uuid,
  applicant_id uuid,
  status application_status,
  created_at timestamptz,
  updated_at timestamptz,
  resume_url text,
  cover_letter text,
  applicant_name text,
  applicant_username text,
  applicant_avatar text,
  applicant_badge jsonb
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH applicant_badges AS (
    SELECT DISTINCT ON (bs.user_id)
      bs.user_id,
      jsonb_build_object('role', bs.role) as badge
    FROM badge_subscriptions bs
    WHERE now() BETWEEN bs.start_date AND bs.end_date
      AND bs.cancelled_at IS NULL
    ORDER BY bs.user_id, bs.end_date DESC
  )
  SELECT 
    ja.id,
    ja.applicant_id,
    ja.status,
    ja.created_at,
    ja.updated_at,
    ja.resume_url,
    ja.cover_letter,
    p.display_name as applicant_name,
    p.username as applicant_username,
    p.avatar_url as applicant_avatar,
    ab.badge as applicant_badge
  FROM job_applications ja
  JOIN profiles p ON p.id = ja.applicant_id
  LEFT JOIN applicant_badges ab ON ab.user_id = ja.applicant_id
  WHERE ja.job_id = job_id
  AND EXISTS (
    SELECT 1 FROM job_listings jl
    WHERE jl.id = job_id
    AND jl.user_id = auth.uid()
  )
  ORDER BY 
    CASE ja.status
      WHEN 'unviewed' THEN 1
      WHEN 'pending' THEN 2
      WHEN 'on_hold' THEN 3
      WHEN 'accepted' THEN 4
      WHEN 'rejected' THEN 5
    END,
    ja.created_at DESC;
$$;