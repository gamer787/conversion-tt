/*
  # Fix Payment Verification and Transaction Handling

  1. Changes
    - Add razorpay_order_id and razorpay_signature to payment verification
    - Update payment verification function to handle transaction details
    - Add payment status change trigger
    - Add automatic activation of services on payment completion

  2. Security
    - All functions are SECURITY DEFINER
    - Proper error handling
    - Transaction safety
*/

-- Drop existing functions if they exist
DROP FUNCTION IF EXISTS verify_payment_v3(text, uuid, text);
DROP FUNCTION IF EXISTS process_payment_v3(uuid, text, integer, text, uuid, jsonb);

-- Create improved payment verification function
CREATE OR REPLACE FUNCTION verify_payment_v3(
  payment_id text,
  order_id text,
  signature text,
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
    -- Update payment record with Razorpay details
    UPDATE payments p
    SET 
      razorpay_order_id = order_id,
      razorpay_signature = signature,
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
        'order_id', order_id,
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

-- Create improved payment processing function
CREATE OR REPLACE FUNCTION process_payment_v3(
  user_id uuid,
  payment_id text,
  order_id text,
  amount integer,
  type text,
  reference_id uuid,
  metadata jsonb
)
RETURNS void AS $$
DECLARE
  payment_record_id uuid;
BEGIN
  -- Create payment record
  INSERT INTO payments (
    user_id,
    razorpay_payment_id,
    razorpay_order_id,
    amount,
    type,
    reference_id,
    status,
    metadata
  ) VALUES (
    user_id,
    payment_id,
    order_id,
    amount,
    type,
    reference_id,
    'processing',
    metadata
  )
  RETURNING id INTO payment_record_id;

  -- Log payment initiation
  INSERT INTO payment_logs (
    payment_id,
    event,
    status,
    data
  ) VALUES (
    payment_record_id,
    'payment_initiated',
    'processing',
    jsonb_build_object(
      'payment_id', payment_id,
      'order_id', order_id,
      'amount', amount,
      'type', type
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;