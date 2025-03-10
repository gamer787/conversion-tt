-- Create storage bucket for resumes if it doesn't exist
DO $$ 
BEGIN
  INSERT INTO storage.buckets (id, name, public)
  VALUES ('resumes', 'resumes', false)
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

-- Create policies for resume storage
CREATE POLICY "resumes_insert_policy"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'resumes'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "resumes_select_policy"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'resumes'
    AND (
      -- Job owner can view resumes
      EXISTS (
        SELECT 1 FROM job_listings jl
        JOIN job_applications ja ON ja.job_id = jl.id
        WHERE jl.user_id = auth.uid()
        AND ja.resume_url LIKE '%' || name
      )
      -- Applicant can view their own resume
      OR EXISTS (
        SELECT 1 FROM job_applications ja
        WHERE ja.applicant_id = auth.uid()
        AND ja.resume_url LIKE '%' || name
      )
    )
  );

CREATE POLICY "resumes_delete_policy"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'resumes'
    AND EXISTS (
      SELECT 1 FROM job_applications ja
      WHERE ja.applicant_id = auth.uid()
      AND ja.resume_url LIKE '%' || name
    )
  );

-- Create function to handle resume upload
CREATE OR REPLACE FUNCTION handle_resume_upload(
  resume_url text,
  job_id uuid,
  cover_letter text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  application_id uuid;
BEGIN
  -- Validate job is open
  IF NOT EXISTS (
    SELECT 1 FROM job_listings
    WHERE id = job_id
    AND status = 'open'
  ) THEN
    RAISE EXCEPTION 'Job is not open for applications';
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