-- Create function to get user's job drafts
CREATE OR REPLACE FUNCTION get_user_job_drafts(user_id uuid)
RETURNS TABLE (
  id uuid,
  title text,
  company_name text,
  company_logo text,
  location text,
  type text,
  salary_range text,
  description text,
  requirements text[],
  benefits text[],
  status job_status,
  created_at timestamptz,
  updated_at timestamptz,
  expires_at timestamptz,
  views integer
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    id,
    title,
    company_name,
    company_logo,
    location,
    type,
    salary_range,
    description,
    requirements,
    benefits,
    status,
    created_at,
    updated_at,
    expires_at,
    views
  FROM job_listings
  WHERE user_id = user_id
  ORDER BY updated_at DESC;
$$;

-- Create function to get job draft by ID
CREATE OR REPLACE FUNCTION get_job_draft(draft_id uuid)
RETURNS TABLE (
  id uuid,
  title text,
  company_name text,
  company_logo text,
  location text,
  type text,
  salary_range text,
  description text,
  requirements text[],
  benefits text[],
  status job_status,
  created_at timestamptz,
  updated_at timestamptz,
  expires_at timestamptz,
  views integer
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    id,
    title,
    company_name,
    company_logo,
    location,
    type,
    salary_range,
    description,
    requirements,
    benefits,
    status,
    created_at,
    updated_at,
    expires_at,
    views
  FROM job_listings
  WHERE id = draft_id
  AND user_id = auth.uid();
$$;