-- Drop existing functions
DROP FUNCTION IF EXISTS get_job_applications;
DROP FUNCTION IF EXISTS get_user_applications;

-- Create function to get job applications with badges
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
  applicant_badge jsonb,
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
BEGIN
  -- Verify user owns the job listing
  IF NOT EXISTS (
    SELECT 1 FROM job_listings jl
    WHERE jl.id = job_id AND jl.user_id = auth.uid()
  ) THEN
    RETURN;
  END IF;

  RETURN QUERY
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
    ab.badge as applicant_badge,
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
  JOIN profiles p ON p.id = ja.applicant_id
  LEFT JOIN applicant_badges ab ON ab.user_id = ja.applicant_id
  WHERE ja.job_id = job_id
  ORDER BY 
    CASE ja.status
      WHEN 'unviewed' THEN 1
      WHEN 'pending' THEN 2
      WHEN 'on_hold' THEN 3
      WHEN 'accepted' THEN 4
      WHEN 'rejected' THEN 5
    END,
    ja.created_at DESC;
END;
$$;

-- Create function to get user applications
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
BEGIN
  -- Validate user ID
  IF user_id IS NULL THEN
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
  WHERE ja.applicant_id = user_id
  ORDER BY ja.created_at DESC;
END;
$$;