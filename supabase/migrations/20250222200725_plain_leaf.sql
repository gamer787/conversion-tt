-- Drop existing functions
DROP FUNCTION IF EXISTS submit_job_application;
DROP FUNCTION IF EXISTS has_applied_to_job;

-- Create function to handle job application submission
CREATE OR REPLACE FUNCTION submit_job_application(
  job_id uuid,
  resume_url text,
  cover_letter text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  application_id uuid;
  job_owner_id uuid;
BEGIN
  -- Get job owner ID and validate job is open
  SELECT user_id INTO job_owner_id
  FROM job_listings
  WHERE id = job_id
  AND status = 'open';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Job is not open for applications';
  END IF;

  -- Prevent applying to own job
  IF job_owner_id = auth.uid() THEN
    RAISE EXCEPTION 'You cannot apply to your own job listing';
  END IF;

  -- Check if user has already applied
  IF EXISTS (
    SELECT 1 FROM job_applications
    WHERE job_id = job_id
    AND applicant_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'You have already applied for this position';
  END IF;

  -- Create application
  INSERT INTO job_applications (
    job_id,
    applicant_id,
    resume_url,
    cover_letter,
    status
  ) VALUES (
    job_id,
    auth.uid(),
    resume_url,
    cover_letter,
    'unviewed'
  )
  RETURNING id INTO application_id;

  RETURN application_id;
END;
$$;

-- Create function to check if user has applied
CREATE OR REPLACE FUNCTION has_applied_to_job(job_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM job_applications
    WHERE job_id = job_id
    AND applicant_id = auth.uid()
  );
$$;

-- Create function to get application count
CREATE OR REPLACE FUNCTION get_job_application_count(job_id uuid)
RETURNS bigint
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COUNT(*)
  FROM job_applications
  WHERE job_id = job_id;
$$;

-- Drop existing policies
DROP POLICY IF EXISTS "applications_select_policy" ON job_applications;

-- Create new restrictive select policy
CREATE POLICY "applications_select_policy"
  ON job_applications FOR SELECT
  USING (
    -- Applicant can only view their own applications
    applicant_id = auth.uid()
    -- Job owner can view all applications for their jobs
    OR EXISTS (
      SELECT 1 FROM job_listings
      WHERE id = job_applications.job_id
      AND user_id = auth.uid()
    )
  );