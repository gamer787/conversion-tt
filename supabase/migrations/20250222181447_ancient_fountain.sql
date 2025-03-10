-- Create storage buckets if they don't exist
DO $$ 
BEGIN
  INSERT INTO storage.buckets (id, name, public)
  VALUES 
    ('logos', 'logos', true),
    ('resumes', 'resumes', true)
  ON CONFLICT (id) DO NOTHING;
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END $$;

-- Drop existing policies
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "logos_select_policy" ON storage.objects;
  DROP POLICY IF EXISTS "logos_insert_policy" ON storage.objects;
  DROP POLICY IF EXISTS "logos_update_policy" ON storage.objects;
  DROP POLICY IF EXISTS "logos_delete_policy" ON storage.objects;
  DROP POLICY IF EXISTS "resumes_select_policy" ON storage.objects;
  DROP POLICY IF EXISTS "resumes_insert_policy" ON storage.objects;
  DROP POLICY IF EXISTS "resumes_update_policy" ON storage.objects;
  DROP POLICY IF EXISTS "resumes_delete_policy" ON storage.objects;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create policies for logos bucket
CREATE POLICY "logos_select_policy" ON storage.objects FOR SELECT
  USING (bucket_id = 'logos');

CREATE POLICY "logos_insert_policy" ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'logos'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "logos_update_policy" ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'logos'
    AND auth.role() = 'authenticated'
    AND auth.uid()::text = (SELECT user_id::text FROM job_listings WHERE company_logo LIKE '%' || name)
  );

CREATE POLICY "logos_delete_policy" ON storage.objects FOR DELETE
  USING (
    bucket_id = 'logos'
    AND auth.role() = 'authenticated'
    AND auth.uid()::text = (SELECT user_id::text FROM job_listings WHERE company_logo LIKE '%' || name)
  );

-- Create policies for resumes bucket
CREATE POLICY "resumes_select_policy" ON storage.objects FOR SELECT
  USING (
    bucket_id = 'resumes'
    AND (
      -- Job owner can view resumes
      auth.uid()::text = (
        SELECT user_id::text 
        FROM job_listings jl
        JOIN job_applications ja ON ja.job_id = jl.id
        WHERE ja.resume_url LIKE '%' || name
      )
      -- Applicant can view their own resume
      OR auth.uid()::text = (
        SELECT applicant_id::text 
        FROM job_applications 
        WHERE resume_url LIKE '%' || name
      )
    )
  );

CREATE POLICY "resumes_insert_policy" ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'resumes'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "resumes_delete_policy" ON storage.objects FOR DELETE
  USING (
    bucket_id = 'resumes'
    AND auth.role() = 'authenticated'
    AND auth.uid()::text = (
      SELECT applicant_id::text 
      FROM job_applications 
      WHERE resume_url LIKE '%' || name
    )
  );

-- Enable RLS on storage.objects if not already enabled
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;