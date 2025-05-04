import React from 'react';
import { ProgressSpinner } from 'primereact/progressspinner';

type LoadingWrapperProps = {
  loading?: boolean;
  children: React.ReactNode;
};

export const LoadingWrapper: React.FC<LoadingWrapperProps> = ({ loading, children }) => {
  return (
    <div className="relative w-full h-full">
      {children}
      {loading && (
        <div className="absolute inset-0 bg-stone-950/50 flex items-center justify-center z-10">
          <ProgressSpinner
            style={{ width: '50px', height: '50px' }}
            strokeWidth="2"
            fill="transparent"
            animationDuration="2s"
          />
        </div>
      )}
    </div>
  );
};
