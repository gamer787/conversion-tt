/*
  # Fix Payment Verification

  1. Changes
    - Add payment verification function
    - Add payment status update trigger
    - Add automatic activation of ads/badges on payment completion

  2. Security
    - All functions are SECURITY DEFINER
    - Proper error handling
    - Transaction safety
*/

-- Create payment verification function
CREATE OR REPLACE FUNCTION verify_payment_v3(
  payment_id text,
  reference_id uuid,
  payment_type text
)
RETURNS void AS $$
DECLARE
  v_payment_record payments%ROWTYPE;
BEGIN
  -- Get payment record
  SELECT * INTO v_payment_record
  FROM payments p
  WHERE p.razorpay_payment_id = payment_id
  AND p.type = payment_type
  AND p.reference_id = reference_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment record not found';
  END IF;

  -- Start transaction
  BEGIN
    -- Update payment status
    UPDATE payments p
    SET 
      status = 'completed',
      completed_at = now()
    WHERE p.id = v_payment_record.id;

    -- Log payment completion
    INSERT INTO payment_logs (
      payment_id,
      event,
      status,
      data
    ) VALUES (
      v_payment_record.id,
      'payment_completed',
      'completed',
      jsonb_build_object(
        'payment_id', payment_id,
        'reference_id', reference_id,
        'type', payment_type
      )
    );

    -- Handle specific payment types
    CASE payment_type
      WHEN 'ad_campaign' THEN
        -- Activate ad campaign
        UPDATE ad_campaigns ac
        SET status = 'active',
            start_time = CURRENT_TIMESTAMP,
            end_time = CURRENT_TIMESTAMP + (duration_hours || ' hours')::interval
        WHERE ac.id = reference_id;
        
      WHEN 'badge_subscription' THEN
        -- Activate badge subscription
        UPDATE badge_subscriptions bs
        SET payment_id = v_payment_record.id,
            start_date = CURRENT_TIMESTAMP,
            end_date = CURRENT_TIMESTAMP + interval '30 days'
        WHERE bs.id = reference_id;
    END CASE;

    -- Commit transaction
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      -- Rollback on error
      ROLLBACK;
      RAISE;
  END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create payment status update trigger function
CREATE OR REPLACE FUNCTION handle_payment_status_change()
RETURNS trigger AS $$
BEGIN
  -- Only handle completed payments
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    -- Handle specific payment types
    CASE NEW.type
      WHEN 'ad_campaign' THEN
        -- Activate ad campaign
        UPDATE ad_campaigns
        SET status = 'active',
            start_time = CURRENT_TIMESTAMP,
            end_time = CURRENT_TIMESTAMP + (duration_hours || ' hours')::interval
        WHERE id = NEW.reference_id;
        
      WHEN 'badge_subscription' THEN
        -- Activate badge subscription
        UPDATE badge_subscriptions
        SET payment_id = NEW.id,
            start_date = CURRENT_TIMESTAMP,
            end_date = CURRENT_TIMESTAMP + interval '30 days'
        WHERE id = NEW.reference_id;
    END CASE;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create payment status trigger
DROP TRIGGER IF EXISTS payment_status_change_trigger ON payments;
CREATE TRIGGER payment_status_change_trigger
  AFTER UPDATE OF status ON payments
  FOR EACH ROW
  WHEN (NEW.status = 'completed' AND OLD.status != 'completed')
  EXECUTE FUNCTION handle_payment_status_change();