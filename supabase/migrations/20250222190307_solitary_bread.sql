-- Drop existing objects in the correct order
DROP FUNCTION IF EXISTS update_application_status CASCADE;
DROP FUNCTION IF EXISTS get_job_applications CASCADE;
DROP FUNCTION IF EXISTS get_user_applications CASCADE;
DROP TABLE IF EXISTS job_applications CASCADE;
DROP TABLE IF EXISTS job_listings CASCADE;
DROP TYPE IF EXISTS job_status CASCADE;
DROP TYPE IF EXISTS application_status CASCADE;

-- Create enums
CREATE TYPE job_status AS ENUM ('draft', 'open', 'closed');
CREATE TYPE application_status AS ENUM ('unviewed', 'pending', 'accepted', 'rejected');

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
  CONSTRAINT valid_dates CHECK (expires_at IS NULL OR expires_at > created_at)
);

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

-- Enable RLS
ALTER TABLE job_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_applications ENABLE ROW LEVEL SECURITY;

-- Create policies for job listings
CREATE POLICY "listings_select_policy"
  ON job_listings FOR SELECT
  USING (
    status = 'open'::job_status
    OR user_id = auth.uid()
  );

CREATE POLICY "listings_insert_policy"
  ON job_listings FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "listings_update_policy"
  ON job_listings FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "listings_delete_policy"
  ON job_listings FOR DELETE
  USING (user_id = auth.uid());

-- Create policies for job applications
CREATE POLICY "applications_select_policy"
  ON job_applications FOR SELECT
  USING (
    applicant_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM job_listings
      WHERE id = job_applications.job_id
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "applications_insert_policy"
  ON job_applications FOR INSERT
  WITH CHECK (
    applicant_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM job_listings
      WHERE id = job_applications.job_id
      AND status = 'open'::job_status
    )
  );

CREATE POLICY "applications_update_policy"
  ON job_applications FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM job_listings
      WHERE id = job_applications.job_id
      AND user_id = auth.uid()
    )
  );

-- Create function to get user's job applications
CREATE OR REPLACE FUNCTION get_user_applications(user_id uuid)
RETURNS TABLE (
  id uuid,
  job_id uuid,
  status application_status,
  created_at timestamptz,
  updated_at timestamptz,
  resume_url text,
  cover_letter text,
  job_title text,
  company_name text,
  company_logo text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    ja.id,
    ja.job_id,
    ja.status,
    ja.created_at,
    ja.updated_at,
    ja.resume_url,
    ja.cover_letter,
    jl.title as job_title,
    jl.company_name,
    jl.company_logo
  FROM job_applications ja
  JOIN job_listings jl ON jl.id = ja.job_id
  WHERE ja.applicant_id = user_id
  ORDER BY ja.created_at DESC;
$$;

-- Create function to get applications for a job
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
  applicant_avatar text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
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
    p.avatar_url as applicant_avatar
  FROM job_applications ja
  JOIN profiles p ON p.id = ja.applicant_id
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
      WHEN 'accepted' THEN 3
      WHEN 'rejected' THEN 4
    END,
    ja.created_at DESC;
$$;

-- Create function to update application status
CREATE OR REPLACE FUNCTION update_application_status(
  application_id uuid,
  new_status application_status
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only allow job owner to update status
  UPDATE job_applications ja
  SET 
    status = new_status,
    updated_at = now()
  FROM job_listings jl
  WHERE ja.id = application_id
  AND ja.job_id = jl.id
  AND jl.user_id = auth.uid();

  RETURN FOUND;
END;
$$;

-- Create storage bucket for resumes if it doesn't exist
DO $$ 
BEGIN
  INSERT INTO storage.buckets (id, name, public)
  VALUES ('resumes', 'resumes', false)
  ON CONFLICT (id) DO NOTHING;
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END $$;

-- Drop existing storage policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "resumes_insert_policy" ON storage.objects;
  DROP POLICY IF EXISTS "resumes_select_policy" ON storage.objects;
  DROP POLICY IF EXISTS "resumes_delete_policy" ON storage.objects;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create policies for resume storage
CREATE POLICY "resumes_insert_policy"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'resumes'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "resumes_select_policy"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'resumes'
    AND (
      -- Job owner can view resumes
      EXISTS (
        SELECT 1 FROM job_listings jl
        JOIN job_applications ja ON ja.job_id = jl.id
        WHERE jl.user_id = auth.uid()
        AND ja.resume_url LIKE '%' || name
      )
      -- Applicant can view their own resume
      OR EXISTS (
        SELECT 1 FROM job_applications ja
        WHERE ja.applicant_id = auth.uid()
        AND ja.resume_url LIKE '%' || name
      )
    )
  );

CREATE POLICY "resumes_delete_policy"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'resumes'
    AND EXISTS (
      SELECT 1 FROM job_applications ja
      WHERE ja.applicant_id = auth.uid()
      AND ja.resume_url LIKE '%' || name
    )
  );