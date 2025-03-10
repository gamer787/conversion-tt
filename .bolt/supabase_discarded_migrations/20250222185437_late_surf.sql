-- Create function to handle application viewing
CREATE OR REPLACE FUNCTION handle_application_view(application_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only allow job owner to update status
  UPDATE job_applications ja
  SET 
    status = CASE 
      WHEN status = 'unviewed' THEN 'pending'::application_status
      ELSE status
    END,
    updated_at = now()
  FROM job_listings jl
  WHERE ja.id = application_id
  AND ja.job_id = jl.id
  AND jl.user_id = auth.uid()
  AND ja.status = 'unviewed';

  RETURN FOUND;
END;
$$;

-- Create function to get application details with automatic status update
CREATE OR REPLACE FUNCTION get_application_details(application_id uuid)
RETURNS TABLE (
  id uuid,
  job_id uuid,
  applicant_id uuid,
  status application_status,
  created_at timestamptz,
  updated_at timestamptz,
  resume_url text,
  cover_letter text,
  applicant_name text,
  applicant_username text,
  applicant_avatar text,
  job_title text,
  company_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- First update status if needed
  PERFORM handle_application_view(application_id);

  -- Then return application details
  RETURN QUERY
  SELECT 
    ja.id,
    ja.job_id,
    ja.applicant_id,
    ja.status,
    ja.created_at,
    ja.updated_at,
    ja.resume_url,
    ja.cover_letter,
    p.display_name as applicant_name,
    p.username as applicant_username,
    p.avatar_url as applicant_avatar,
    jl.title as job_title,
    jl.company_name
  FROM job_applications ja
  JOIN profiles p ON p.id = ja.applicant_id
  JOIN job_listings jl ON jl.id = ja.job_id
  WHERE ja.id = application_id
  AND (
    -- Applicant can view their own application
    ja.applicant_id = auth.uid()
    -- Job owner can view the application
    OR jl.user_id = auth.uid()
  );
END;
$$;