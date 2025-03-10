-- Drop existing function
DROP FUNCTION IF EXISTS get_user_applications;

-- Create improved function with proper parameter handling
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
BEGIN
  -- Validate input
  IF target_user_id IS NULL THEN
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
  WHERE ja.applicant_id = target_user_id
  ORDER BY ja.created_at DESC;
END;
$$;