import React from 'react';
import { AlertCircle } from 'lucide-react';

interface PaymentModalProps {
  onConfirm: () => void;
  onCancel: () => void;
  loading: boolean;
  error: string | null;
  success: string | null;
  duration: number;
  radius: number;
  estimatedReach: number;
  price: number;
}

export function PaymentModal({
  onConfirm,
  onCancel,
  loading,
  error,
  success,
  duration,
  radius,
  estimatedReach,
  price
}: PaymentModalProps) {
  return (
    <div className="fixed inset-0 bg-black/90 backdrop-blur-sm flex items-center justify-center z-50 p-4">
      <div className="bg-gradient-to-br from-gray-900 to-gray-800 rounded-lg w-full max-w-md p-6 border border-gray-800 relative">
        {loading && (
          <div className="absolute inset-0 bg-gray-900/50 backdrop-blur-sm flex items-center justify-center rounded-lg">
            <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-cyan-400"></div>
          </div>
        )}
        <div className="flex items-center space-x-2 text-yellow-400 mb-4">
          <AlertCircle className="w-6 h-6" />
          <h3 className="text-lg font-semibold">Payment Gateway</h3>
        </div>
        <div className="space-y-4 mb-6">
          <p className="text-gray-300">
            Campaign Summary:
          </p>
          <div className="bg-gray-800 p-4 rounded-lg space-y-2">
            <div className="flex justify-between">
              <span className="text-gray-400">Duration:</span>
              <span className="text-white">{duration} hours</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-400">Radius:</span>
              <span className="text-white">{radius} km</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-400">Estimated Reach:</span>
              <span className="text-white">{estimatedReach.toLocaleString()}+ users</span>
            </div>
            <div className="flex justify-between pt-2 border-t border-gray-700">
              <span className="text-gray-400">Total Price:</span>
              <span className="text-lg font-bold text-cyan-400">₹{price}</span>
            </div>
          </div>
        </div>
        <div className="flex space-x-4">
          <button
            onClick={onCancel}
            disabled={loading}
            className="flex-1 py-3 px-4 bg-gray-800 text-white rounded-lg hover:bg-gray-700 transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            disabled={loading}
            className="flex-1 py-3 px-4 bg-gradient-to-r from-cyan-400 to-purple-400 text-gray-900 rounded-lg hover:from-cyan-300 hover:to-purple-300 transition-colors font-semibold disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
          >
            {loading ? (
              <>
                <div className="w-5 h-5 border-2 border-gray-900 border-t-transparent rounded-full animate-spin mr-2" />
                Processing...
              </>
            ) : (
              'Pay Now'
            )}
          </button>
        </div>
        {error && !success && (
          <div className="mt-4 p-3 bg-red-400/10 text-red-400 border border-red-400/20 rounded-lg text-sm">
            {error}
          </div>
        )}
        {success && (
          <div className="mt-4 p-3 bg-green-400/10 text-green-400 border border-green-400/20 rounded-lg text-sm">
            {success}
          </div>
        )}
      </div>
    </div>
  );
}