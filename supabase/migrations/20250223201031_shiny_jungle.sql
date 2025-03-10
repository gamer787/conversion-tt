-- Drop existing function
DROP FUNCTION IF EXISTS get_user_applications;

-- Create improved function with both parameter names for backward compatibility
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
  company_logo text,
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
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Use the provided user_id or fall back to authenticated user
  v_user_id := COALESCE(user_id, auth.uid());
  
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
    ja.applicant_email,
    ja.applicant_phone,
    ja.applicant_salary,
    ja.salary_negotiable,
    ja.applicant_notice,
    ja.applicant_company,
    ja.applicant_position,
    ja.applicant_experience,
    ja.applicant_location,
    ja.can_relocate,
    ja.preferred_locations
  FROM job_applications ja
  JOIN job_listings jl ON jl.id = ja.job_id
  WHERE ja.applicant_id = v_user_id
  ORDER BY ja.created_at DESC;
END;
$$;