import { ErrorBoundary, FallbackProps } from 'react-error-boundary';
import { PrimeReactProvider } from 'primereact/api';
import { useEffect, useRef } from 'react';
import { ToastProvider } from '@/hooks/Mapper/ToastProvider';
import { PageCharactersProvider } from './PageCharactersProvider';
import { PageCharactersPage } from './PageCharactersPage';
import { PAGE_CHARACTERS_EVENT } from './constants';
import { usePageCharactersHandlers } from './hooks/usePageCharactersHandlers';
import type { PageCharactersHandlers, PageCharactersHooks } from './types';
import { PageCharactersOutCommand } from './types';
import styles from './PageCharactersRoot.module.scss';
import '../common-styles/main.scss';

export interface PageCharactersRootProps {
  hooks: PageCharactersHooks;
}

export type PageCharactersErrorFallbackProps = FallbackProps;

export const PageCharactersErrorFallback = ({ error, resetErrorBoundary }: PageCharactersErrorFallbackProps) => {
  return (
    <div className={styles.fallbackPage} role="alert">
      <div className="max-w-lg border border-red-900 bg-red-950/40 p-6">
        <h1 className="text-lg font-semibold text-red-200">Characters prototype failed to render</h1>
        <p className="mt-2 text-sm text-red-300">{error.message}</p>
        <button type="button" className={styles.retryButton} onClick={resetErrorBoundary}>
          Try again
        </button>
      </div>
    </div>
  );
};

export const PageCharactersRoot = ({ hooks }: PageCharactersRootProps) => {
  const providerRef = useRef<PageCharactersHandlers>(null);
  const hooksRef = useRef(hooks);
  const handlerRefs = useRef([providerRef]);
  const { handleCommand, handlePageCharactersEvent } = usePageCharactersHandlers(handlerRefs.current, hooksRef);

  useEffect(() => {
    const eventRef = hooksRef.current.handleEvent(PAGE_CHARACTERS_EVENT, handlePageCharactersEvent);
    void handleCommand({ type: PageCharactersOutCommand.init, data: {} });

    return () => {
      hooksRef.current.removeHandleEvent(eventRef);
    };
  }, [handleCommand, handlePageCharactersEvent]);

  return (
    <PrimeReactProvider>
      <ToastProvider>
        <ErrorBoundary FallbackComponent={PageCharactersErrorFallback}>
          <PageCharactersProvider fwdRef={providerRef} outCommand={handleCommand}>
            <PageCharactersPage />
          </PageCharactersProvider>
        </ErrorBoundary>
      </ToastProvider>
    </PrimeReactProvider>
  );
};
