import { PrimeReactProvider } from 'primereact/api';
import { ErrorBoundary } from 'react-error-boundary';

import { MapHandlers } from '@/hooks/Mapper/types/mapHandlers.ts';
import { ErrorInfo, useCallback, useEffect, useRef } from 'react';
import { ReactFlowProvider } from 'reactflow';
import { useMapperHandlers } from './useMapperHandlers';

import { MapRootContent } from '@/hooks/Mapper/components/mapRootContent/MapRootContent.tsx';
import { MapRootProvider } from '@/hooks/Mapper/mapRootProvider';
import './common-styles/main.scss';
import { ToastProvider } from '@/hooks/Mapper/ToastProvider.tsx';

const ErrorFallback = () => {
  return <div className="!z-100 absolute w-screen h-screen bg-transparent"></div>;
};

export default function MapRoot({ hooks }) {
  const providerRef = useRef<MapHandlers>(null);
  const hooksRef = useRef<any>(hooks);

  const mapperHandlerRefs = useRef([providerRef]);

  const { handleCommand, handleMapEvent } = useMapperHandlers(mapperHandlerRefs.current, hooksRef);

  const logError = useCallback((error: Error, info: ErrorInfo) => {
    if (!hooksRef.current) {
      return;
    }
    hooksRef.current.onError(error, info.componentStack);
  }, []);

  useEffect(() => {
    if (!hooksRef.current) {
      return;
    }

    hooksRef.current.handleEvent('map_event', handleMapEvent);
  }, []);

  return (
    <PrimeReactProvider>
      <ToastProvider>
        <MapRootProvider fwdRef={providerRef} outCommand={handleCommand}>
          <ErrorBoundary FallbackComponent={ErrorFallback} onError={logError}>
            <ReactFlowProvider>
              <MapRootContent />
            </ReactFlowProvider>
          </ErrorBoundary>
        </MapRootProvider>
      </ToastProvider>
    </PrimeReactProvider>
  );
}
