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
BEGIN
  -- Validate job is open
  IF NOT EXISTS (
    SELECT 1 FROM job_listings
    WHERE id = job_id
    AND status = 'open'
  ) THEN
    RAISE EXCEPTION 'Job is not open for applications';
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