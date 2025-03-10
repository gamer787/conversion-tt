import { loadRazorpayScript, initializePayment } from './razorpay';
import { supabase } from './supabase';

async function handleAdPayment(
  adDetails: {
    duration_hours: number;
    radius_km: number;
    price: number;
    content_id: string;
  },
  userDetails: {
    name: string;
    email: string;
  }
) {
  try {
    // Input validation
    if (!adDetails.price || adDetails.price <= 0) {
      throw new Error('Please select a valid payment amount');
    }

    if (!adDetails.content_id) {
      throw new Error('Please select content to promote');
    }

    if (!userDetails.name || !userDetails.email) {
      throw new Error('Please provide your name and email');
    }

    // Get current user
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError) throw new Error('Authentication failed. Please sign in again.');
    if (!user) throw new Error('Please sign in to continue');

    // Validate environment variables
    if (!import.meta.env.VITE_RAZORPAY_KEY_ID) {
      throw new Error('Payment system is not properly configured');
    }

    // Load Razorpay script
    const isLoaded = await loadRazorpayScript();
    if (!isLoaded) {
      throw new Error('Failed to load payment system. Please refresh and try again.');
    }

    // Get price tier ID
    const { data: priceTier, error: tierError } = await supabase
      .from('ad_price_tiers')
      .select('id')
      .eq('duration_hours', adDetails.duration_hours)
      .eq('radius_km', adDetails.radius_km)
      .eq('price', adDetails.price)
      .single();

    if (tierError || !priceTier) {
      throw new Error('Invalid price tier selected. Please try again.');
    }

    // Initialize payment
    const response = await initializePayment({
      amount: adDetails.price,
      currency: 'INR', // Keep INR as currency
      name: 'Lotus Scientific Solutions',
      description: `${adDetails.duration_hours}h campaign - ${adDetails.radius_km}km radius`,
      prefill: {
        name: userDetails.name,
        email: userDetails.email
      },
      notes: {
        type: 'ad_campaign',
        content_id: adDetails.content_id,
        duration_hours: adDetails.duration_hours.toString(),
        radius_km: adDetails.radius_km.toString()
      }
    });

    if (!response?.razorpay_payment_id) {
      throw new Error('Payment could not be verified. Please try again.');
    }

    // Create campaign after successful payment
    const { data: campaign, error: campaignError } = await supabase
      .from('ad_campaigns')
      .insert({
        user_id: user.id,
        content_id: adDetails.content_id,
        duration_hours: adDetails.duration_hours,
        radius_km: adDetails.radius_km,
        price: adDetails.price,
        price_tier_id: priceTier.id,
        status: 'pending',
        start_time: new Date().toISOString(),
        end_time: new Date(Date.now() + adDetails.duration_hours * 60 * 60 * 1000).toISOString()
      })
      .select()
      .single();

    if (campaignError) {
      throw new Error('Unable to create campaign. Please try again or contact support if the issue persists.');
    }

    if (!campaign) {
      throw new Error('Failed to create campaign - no data returned');
    }

    // Process payment
    const { error: processError } = await supabase.rpc('process_payment_v3', {
      user_id: user.id,
      payment_id: response.razorpay_payment_id,
      amount: adDetails.price,
      type: 'ad_campaign',
      reference_id: campaign.id,
      metadata: {
        duration_hours: adDetails.duration_hours,
        radius_km: adDetails.radius_km,
        price_tier_id: priceTier.id
      }
    });

    if (processError) throw processError;

    // Verify payment
    const { error: verifyError } = await supabase.rpc('verify_payment_v3', {
      payment_id: response.razorpay_payment_id,
      reference_id: campaign.id,
      payment_type: 'ad_campaign'
    });

    if (verifyError) throw verifyError;

    return { success: true, campaign };
  } catch (error) {
    // Log the full error for debugging
    console.error('Payment error:', error instanceof Error ? error.message : error);

    let campaignId;
    try {
      // Get the campaign ID if it exists
      const { data: campaign } = await supabase
        .from('ad_campaigns')
        .select('id')
        .eq('content_id', adDetails.content_id)
        .eq('status', 'pending')
        .single();
      
      campaignId = campaign?.id;
    } catch (err) {
      console.error('Error getting campaign ID:', err);
    }

    // Clean up campaign on payment failure
    try {
      if (campaignId) {
        await supabase.rpc('handle_payment_failure_v3', {
          payment_id: response?.razorpay_payment_id || ''
        });
      }
    } catch (cleanupError) {
      console.error('Error cleaning up failed campaign:', cleanupError instanceof Error ? cleanupError.message : cleanupError);
    }

    const errorMessage = error instanceof Error 
      ? error.message
      : 'Payment failed. Please try again or contact support if the issue persists.';
    
    return { 
      success: false, 
      error: errorMessage
    };
  }
}

async function handleBadgePayment(
  badgeDetails: {
    category: string;
    role: string;
    price: number;
  },
  userDetails: {
    name: string;
    email: string;
  }
) {
  try {
    // Input validation
    if (!badgeDetails.price || badgeDetails.price <= 0) {
      throw new Error('Please select a valid badge tier');
    }

    if (!badgeDetails.category || !badgeDetails.role) {
      throw new Error('Please select a badge category and role');
    }

    if (!userDetails.name || !userDetails.email) {
      throw new Error('Please provide your name and email');
    }

    // Get current user
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError) throw new Error('Authentication failed. Please sign in again.');
    if (!user) throw new Error('Please sign in to continue');

    // Load Razorpay script
    const isLoaded = await loadRazorpayScript();
    if (!isLoaded) {
      throw new Error('Unable to load payment system. Please check your internet connection and try again.');
    }

    const startDate = new Date();
    const endDate = new Date();
    endDate.setDate(endDate.getDate() + 30);
      
    // Create pending payment record
    const { data: payment, error: paymentError } = await supabase
      .from('payments')
      .insert({
        user_id: user.id,
        amount: badgeDetails.price,
        currency: 'INR',
        type: 'badge_subscription',
        status: 'pending',
        metadata: {
          category: badgeDetails.category,
          role: badgeDetails.role
        }
      })
      .select()
      .single();

    if (paymentError) {
      throw new Error('Unable to initialize payment. Please try again or contact support.');
    }

    // Create pending subscription
    const { data: subscription, error: subscriptionError } = await supabase
      .from('badge_subscriptions')
      .insert({
        user_id: user.id,
        category: badgeDetails.category,
        role: badgeDetails.role,
        price: badgeDetails.price,
        payment_id: payment.id,
        start_date: startDate.toISOString(), 
        end_date: endDate.toISOString()
      })
      .select()
      .single();

    if (subscriptionError) {
      // Clean up payment if subscription creation fails
      await supabase
        .from('payments')
        .delete()
        .eq('id', payment.id);
        
      throw new Error('Unable to create badge subscription. Please try again.');
    }

    // Initialize Razorpay payment after records are created
    const response = await initializePayment({
      amount: badgeDetails.price,
      currency: 'INR',
      name: 'Lotus Scientific Solutions',
      description: `${badgeDetails.role} Badge - 30 Days`,
      prefill: {
        name: userDetails.name,
        email: userDetails.email
      },
      notes: {
        type: 'badge_subscription',
        payment_id: payment.id,
        subscription_id: subscription.id,
        category: badgeDetails.category,
        role: badgeDetails.role
      }
    });

    if (!response || !response.razorpay_payment_id || !response.razorpay_order_id || !response.razorpay_signature) {
      // Clean up pending records if payment fails
      await Promise.all([
        supabase.from('badge_subscriptions').delete().eq('id', subscription.id),
        supabase.from('payments').delete().eq('id', payment.id)
      ]);
      throw new Error('Payment could not be verified. Please try again.');
    }

    // Process payment
    const { error: processError } = await supabase.rpc('process_payment_v3', {
      user_id: user.id,
      payment_id: response.razorpay_payment_id,
      order_id: response.razorpay_order_id,
      amount: badgeDetails.price,
      type: 'badge_subscription',
      reference_id: subscription.id,
      metadata: {
        category: badgeDetails.category,
        role: badgeDetails.role
      }
    });

    if (processError) throw processError;

    // Verify payment
    const { error: verifyError } = await supabase.rpc('verify_payment_v3', {
      payment_id: response.razorpay_payment_id,
      order_id: response.razorpay_order_id,
      signature: response.razorpay_signature,
      reference_id: subscription.id,
      payment_type: 'badge_subscription'
    });

    if (verifyError) throw verifyError;

    return { success: true, subscription };
  } catch (err) {
    // Clean up any pending records
    try {
      if (payment?.id) {
        await supabase.from('payments').delete().eq('id', payment.id);
      }
      if (subscription?.id) {
        await supabase.from('badge_subscriptions').delete().eq('id', subscription.id);
      }
    } catch (cleanupError) {
      console.error('Error cleaning up failed payment:', cleanupError);
    }

    const errorMessage = error instanceof Error 
      ? error.message
      : 'Payment failed. Please try again or contact support if the issue persists.';
    
    console.error('Payment error:', errorMessage);
    return { 
      success: false, 
      error: errorMessage
    };
  }
}

export { handleAdPayment, handleBadgePayment };