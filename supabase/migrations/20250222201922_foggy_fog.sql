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

-- Create function to submit job application
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