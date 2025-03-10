-- Drop existing function
DROP FUNCTION IF EXISTS delete_job_listing;

-- Create improved function with proper parameter name
CREATE OR REPLACE FUNCTION delete_job_listing(job_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  job_record job_listings%ROWTYPE;
BEGIN
  -- Get job details first
  SELECT * INTO job_record
  FROM job_listings
  WHERE id = job_id
  AND user_id = auth.uid();

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- Delete associated applications
  DELETE FROM job_applications
  WHERE job_id = job_record.id;

  -- Delete the job listing
  DELETE FROM job_listings
  WHERE id = job_record.id;

  -- Delete company logo if it exists
  IF job_record.company_logo IS NOT NULL THEN
    DELETE FROM storage.objects
    WHERE bucket_id = 'logos'
    AND name = (
      SELECT regexp_replace(job_record.company_logo, '^.*/([^/]+)$', '\1')
    );
  END IF;

  RETURN true;
END;
$$;