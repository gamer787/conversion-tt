import { serve } from 'https://deno.fresh.dev/std/http/server.ts';
import Razorpay from 'npm:razorpay';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '86400',
};

serve(async (req) => {
  try {
    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
      return new Response('ok', { headers: corsHeaders });
    }

    // Validate request method
    if (req.method !== 'POST') {
      throw new Error('Method not allowed');
    }

    // Validate content type
    const contentType = req.headers.get('content-type');
    if (!contentType?.includes('application/json')) {
      throw new Error('Content-Type must be application/json');
    }

    // Get and validate environment variables
    const key_id = Deno.env.get('RAZORPAY_KEY_ID');
    const key_secret = Deno.env.get('RAZORPAY_KEY_SECRET');

    if (!key_id || !key_secret) {
      throw new Error('Payment system is not properly configured');
    }

    // Initialize Razorpay
    const razorpay = new Razorpay({
      key_id,
      key_secret
    });

    // Parse request body
    const body = await req.json();
    if (!body) {
      throw new Error('Invalid request body');
    }

    const { amount, currency = 'INR', notes, description } = body;

    // Validate amount
    if (!amount || typeof amount !== 'number' || amount <= 0) {
      throw new Error('Invalid payment amount provided');
    }

    // Create Razorpay order
    const order = await razorpay.orders.create({
      amount: Math.round(amount * 100), // Convert to paise
      currency,
      notes: {
        ...notes,
        description
      },
      receipt: `receipt_${Date.now()}`,
      payment_capture: 1 // Auto capture payment
    });

    return new Response(
      JSON.stringify({
        id: order.id,
        amount: order.amount,
        currency: order.currency,
        status: 'created'
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders
        },
        status: 200,
      }
    );
  } catch (error) {
    console.error('Razorpay error:', error);

    const errorMessage = error instanceof Error 
      ? error.message 
      : 'An unexpected error occurred';

    return new Response(
      JSON.stringify({
        error: errorMessage,
        status: 'error'
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders
        },
        status: error instanceof Error && error.message === 'Method not allowed' ? 405 : 
                error instanceof Error && error.message === 'Invalid request format' ? 400 : 500,
      }
    );
  }
});