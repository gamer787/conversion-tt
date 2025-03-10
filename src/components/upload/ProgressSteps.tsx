import React from 'react';

interface ProgressStepsProps {
  currentStep: 'type' | 'upload' | 'select' | 'edit' | 'details';
  steps: string[];
}

export function ProgressSteps({ currentStep, steps }: ProgressStepsProps) {
  const currentIndex = steps.indexOf(currentStep);

  return (
    <div className="flex items-center justify-between mb-8">
      {steps.map((step, i) => (
        <React.Fragment key={step}>
          <div
            className={`w-3 h-3 rounded-full ${
              step === currentStep
                ? 'bg-cyan-400'
                : i < currentIndex
                ? 'bg-cyan-400/50'
                : 'bg-gray-700'
            }`}
          />
          {i < steps.length - 1 && (
            <div
              className={`flex-1 h-0.5 ${
                i < currentIndex
                  ? 'bg-cyan-400/50'
                  : 'bg-gray-700'
              }`}
            />
          )}
        </React.Fragment>
      ))}
    </div>
  );
}