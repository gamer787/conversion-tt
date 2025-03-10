import { useState } from 'react';
import { handleAdPayment } from '../lib/payments';
import type { AdCampaign } from '../types/ads';

interface UseAdPaymentProps {
  onSuccess: () => void;
  onError: (error: string) => void;
}

export function useAdPayment({ onSuccess, onError }: UseAdPaymentProps) {
  const [loading, setLoading] = useState(false);

  const processPayment = async (
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
  ) => {
    try {
      setLoading(true);
      
      const { success, error, campaign } = await handleAdPayment(
        adDetails,
        userDetails
      );

      if (!success || error) throw error;

      onSuccess();
      return campaign as AdCampaign;
    } catch (err) {
      onError(err instanceof Error ? err.message : 'Failed to process payment');
      return null;
    } finally {
      setLoading(false);
    }
  };

  return {
    loading,
    processPayment
  };
}