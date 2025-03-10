-- Create storage bucket for resumes if it doesn't exist
DO $$ 
BEGIN
  INSERT INTO storage.buckets (id, name, public)
  VALUES ('resumes', 'resumes', true)
  ON CONFLICT (id) DO NOTHING;
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END $$;

-- Drop existing storage policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "resumes_insert_policy" ON storage.objects;
  DROP POLICY IF EXISTS "resumes_select_policy" ON storage.objects;
  DROP POLICY IF EXISTS "resumes_delete_policy" ON storage.objects;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create simplified storage policies for resumes
CREATE POLICY "resumes_insert_policy"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'resumes'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "resumes_select_policy"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'resumes');

CREATE POLICY "resumes_delete_policy"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'resumes'
    AND auth.uid()::text = SPLIT_PART(name, '/', 1)
  );

-- Create function to handle resume upload and job application
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