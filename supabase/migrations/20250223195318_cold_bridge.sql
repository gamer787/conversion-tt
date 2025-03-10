-- Drop existing function
DROP FUNCTION IF EXISTS submit_job_application;

-- Create improved function with proper parameter naming
CREATE OR REPLACE FUNCTION submit_job_application(
  target_job_id uuid,
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
  WHERE id = target_job_id
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
    WHERE job_id = target_job_id
    AND applicant_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'You have already applied for this position';
  END IF;

  -- Validate resume URL
  IF resume_url IS NULL OR resume_url = '' THEN
    RAISE EXCEPTION 'Resume is required';
  END IF;

  -- Create application
  INSERT INTO job_applications (
    job_id,
    applicant_id,
    resume_url,
    cover_letter,
    status
  ) VALUES (
    target_job_id,
    auth.uid(),
    resume_url,
    cover_letter,
    'unviewed'
  )
  RETURNING id INTO application_id;

  RETURN application_id;
END;
$$;