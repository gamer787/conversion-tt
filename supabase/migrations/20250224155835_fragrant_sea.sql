-- Create payment_logs table if it doesn't exist
DO $$ 
BEGIN
  CREATE TABLE IF NOT EXISTS payment_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id uuid REFERENCES payments(id) NOT NULL,
    event text NOT NULL,
    status text NOT NULL,
    data jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
  );
EXCEPTION
  WHEN duplicate_table THEN
    NULL;
END $$;

-- Enable RLS on payment_logs if not already enabled
ALTER TABLE payment_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policy if it exists
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "users_view_own_payment_logs_v3" ON payment_logs;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create RLS policy for payment_logs
CREATE POLICY "users_view_own_payment_logs_v3"
  ON payment_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM payments
      WHERE id = payment_logs.payment_id
      AND user_id = auth.uid()
    )
  );

-- Drop existing indexes if they exist
DROP INDEX IF EXISTS idx_payment_logs_payment_v3;
DROP INDEX IF EXISTS idx_payment_logs_created_v3;

-- Create indexes for better performance
CREATE INDEX idx_payment_logs_payment_v3 ON payment_logs(payment_id);
CREATE INDEX idx_payment_logs_created_v3 ON payment_logs(created_at);