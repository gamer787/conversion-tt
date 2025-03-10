-- Add new columns to job_applications table
ALTER TABLE job_applications
ADD COLUMN IF NOT EXISTS applicant_email text,
ADD COLUMN IF NOT EXISTS applicant_phone text,
ADD COLUMN IF NOT EXISTS applicant_salary text,
ADD COLUMN IF NOT EXISTS salary_negotiable boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS applicant_notice text,
ADD COLUMN IF NOT EXISTS applicant_company text,
ADD COLUMN IF NOT EXISTS applicant_position text,
ADD COLUMN IF NOT EXISTS applicant_experience text,
ADD COLUMN IF NOT EXISTS applicant_location text,
ADD COLUMN IF NOT EXISTS can_relocate boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS preferred_locations text[];

-- Drop existing functions
DROP FUNCTION IF EXISTS submit_job_application;
DROP FUNCTION IF EXISTS get_user_applications;

-- Create improved function with all fields
CREATE OR REPLACE FUNCTION submit_job_application(
  target_job_id uuid,
  resume_url text,
  cover_letter text,
  applicant_email text,
  applicant_phone text,
  applicant_salary text,
  salary_negotiable boolean,
  applicant_notice text,
  applicant_company text,
  applicant_position text,
  applicant_experience text,
  applicant_location text,
  can_relocate boolean,
  preferred_locations text[]
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

  -- Validate required fields
  IF resume_url IS NULL OR resume_url = '' THEN
    RAISE EXCEPTION 'Resume is required';
  END IF;

  IF applicant_email IS NULL OR applicant_email = '' THEN
    RAISE EXCEPTION 'Email is required';
  END IF;

  IF applicant_phone IS NULL OR applicant_phone = '' THEN
    RAISE EXCEPTION 'Phone number is required';
  END IF;

  -- Create application with all fields
  INSERT INTO job_applications (
    job_id,
    applicant_id,
    resume_url,
    cover_letter,
    applicant_email,
    applicant_phone,
    applicant_salary,
    salary_negotiable,
    applicant_notice,
    applicant_company,
    applicant_position,
    applicant_experience,
    applicant_location,
    can_relocate,
    preferred_locations,
    status
  ) VALUES (
    target_job_id,
    auth.uid(),
    resume_url,
    cover_letter,
    applicant_email,
    applicant_phone,
    applicant_salary,
    salary_negotiable,
    applicant_notice,
    applicant_company,
    applicant_position,
    applicant_experience,
    applicant_location,
    can_relocate,
    preferred_locations,
    'unviewed'
  )
  RETURNING id INTO application_id;

  RETURN application_id;
END;
$$;

-- Create improved function with additional fields
CREATE OR REPLACE FUNCTION get_user_applications(target_user_id uuid)
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
  company_logo text,
  applicant_position text,
  applicant_salary text,
  applicant_notice text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Use the authenticated user's ID if no target_user_id is provided
  v_user_id := COALESCE(target_user_id, auth.uid());
  
  -- Validate user ID
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User ID is required';
  END IF;

  -- Return applications for the user with explicit table aliases
  RETURN QUERY
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
    jl.company_logo,
    ja.applicant_position,
    ja.applicant_salary,
    ja.applicant_notice
  FROM job_applications ja
  JOIN job_listings jl ON jl.id = ja.job_id
  WHERE ja.applicant_id = v_user_id
  ORDER BY ja.created_at DESC;
END;
$$;