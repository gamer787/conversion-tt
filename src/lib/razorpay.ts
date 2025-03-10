declare global {
  interface Window {
    Razorpay: any;
  }
}

export interface PaymentOptions {
  amount: number;
  currency?: string;
  name: string;
  description: string;
  notes?: Record<string, string>;
  prefill?: {
    name?: string;
    email?: string;
    contact?: string;
  };
}

interface RazorpayResponse {
  razorpay_payment_id: string;
  razorpay_order_id: string;
  razorpay_signature: string;
}

export async function loadRazorpayScript(): Promise<boolean> {
  return new Promise((resolve) => {
    if (typeof window.Razorpay !== 'undefined') {
      resolve(true);
      return;
    }

    const script = document.createElement('script');
    script.src = 'https://checkout.razorpay.com/v1/checkout.js';
    script.async = true;
    script.defer = true;
    script.crossOrigin = 'anonymous';

    let timeoutId: number;

    script.onload = () => {
      clearTimeout(timeoutId);
      resolve(true);
    };
    script.onerror = () => {
      clearTimeout(timeoutId);
      resolve(false);
    };

    // Add timeout for script loading
    timeoutId = window.setTimeout(() => {
      resolve(false);
    }, 10000);

    document.body.appendChild(script);
  });
}

export function initializePayment(options: PaymentOptions): Promise<RazorpayResponse> {
  return new Promise((resolve, reject) => {
    try {
      // Validate required fields
      if (!options.amount || options.amount <= 0) {
        reject(new Error('Invalid payment amount'));
        return;
      }

      if (!options.name || !options.description) {
        reject(new Error('Payment details are incomplete'));
        return;
      }

      // Validate environment variables
      const key_id = import.meta.env.VITE_RAZORPAY_KEY_ID;
      if (!key_id) {
        reject(new Error('Payment system is not properly configured'));
        return;
      }

      // Configure Razorpay options
      const rzpOptions = {
        key: key_id,
        amount: Math.round(options.amount * 100), // Convert to paise
        currency: options.currency || 'INR',
        name: options.name,
        description: options.description,
        prefill: options.prefill,
        notes: options.notes,
        retry: {
          enabled: true,
          max_count: 3
        },
        timeout: 300,
        theme: {
          color: '#00E5FF'
        },
        handler: function(response: any) {
          if (!response?.razorpay_payment_id) {
            reject(new Error('Payment verification failed'));
            return;
          }
          resolve(response);
        },
        modal: {
          ondismiss: () => {
            reject(new Error('Payment cancelled'));
          },
          escape: false,
          animation: true,
          backdropclose: false,
          handleback: true,
          confirm_close: true
        }
      };

      // Load Razorpay script if not already loaded
      loadRazorpayScript().then(loaded => {
        if (!loaded) {
          reject(new Error('Failed to load payment system. Please try again.'));
          return;
        }

        const rzp = new window.Razorpay({
          ...rzpOptions,
          retry: {
            enabled: true,
            max_count: 3
          },
          timeout: 300,
          config: {
            display: {
              language: 'en',
              hide_topbar: false
            }
          }
        });

        try {
          rzp.open();
        } catch (error) {
          const errorMessage = error instanceof Error 
            ? error.message 
            : 'Unable to open payment window';
          reject(new Error(errorMessage));
        }
      });
    } catch (error) {
      const errorMessage = error instanceof Error 
        ? error.message 
        : 'An unexpected error occurred';
      reject(new Error(errorMessage));
    }
  });
}