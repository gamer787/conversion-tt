-- Drop existing function
DROP FUNCTION IF EXISTS get_job_applications;

-- Create improved function with proper parameter naming
CREATE OR REPLACE FUNCTION get_job_applications(target_job_id uuid)
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
  applicant_badge jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify user owns the job listing
  IF NOT EXISTS (
    SELECT 1 FROM job_listings jl
    WHERE jl.id = target_job_id AND jl.user_id = auth.uid()
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
    ab.badge as applicant_badge
  FROM job_applications ja
  JOIN profiles p ON p.id = ja.applicant_id
  LEFT JOIN applicant_badges ab ON ab.user_id = ja.applicant_id
  WHERE ja.job_id = target_job_id
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