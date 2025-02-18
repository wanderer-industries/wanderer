import { useState, useCallback, useRef } from 'react';
import { ExtendedSystemSignature, schedulePendingAdditionForSig } from '../helpers/contentHelpers';
import { UsePendingAdditionParams } from './types';
import { FINAL_DURATION_MS } from '../constants';

export function usePendingAdditions({ setSignatures }: UsePendingAdditionParams) {
  const [pendingUndoAdditions, setPendingUndoAdditions] = useState<ExtendedSystemSignature[]>([]);
  const pendingAdditionMapRef = useRef<Record<string, { finalUntil: number; finalTimeoutId: number }>>({});

  const processAddedSignatures = useCallback(
    (added: ExtendedSystemSignature[]) => {
      if (!added.length) return;
      const now = Date.now();
      setSignatures(prev => [
        ...prev,
        ...added.map(sig => ({
          ...sig,
          pendingAddition: true,
          pendingUntil: now + FINAL_DURATION_MS,
        })),
      ]);
      added.forEach(sig => {
        schedulePendingAdditionForSig(
          sig,
          FINAL_DURATION_MS,
          setSignatures,
          pendingAdditionMapRef,
          setPendingUndoAdditions,
        );
      });
    },
    [setSignatures],
  );

  const clearPendingAdditions = useCallback(() => {
    Object.values(pendingAdditionMapRef.current).forEach(({ finalTimeoutId }) => {
      clearTimeout(finalTimeoutId);
    });
    pendingAdditionMapRef.current = {};
    setSignatures(prev =>
      prev.map(x => (x.pendingAddition ? { ...x, pendingAddition: false, pendingUntil: undefined } : x)),
    );
    setPendingUndoAdditions([]);
  }, [setSignatures]);

  return {
    pendingUndoAdditions,
    setPendingUndoAdditions,
    pendingAdditionMapRef,
    processAddedSignatures,
    clearPendingAdditions,
  };
}
