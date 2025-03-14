import { useCallback, useRef, useState } from 'react';
import { UsePendingAdditionParams } from './types';
import { FINAL_DURATION_MS } from '../constants';
import { ExtendedSystemSignature } from '@/hooks/Mapper/types';
import { schedulePendingAdditionForSig } from '../helpers/contentHelpers';

export const usePendingAdditions = ({ setSignatures, deletionTiming }: UsePendingAdditionParams) => {
  const [pendingUndoAdditions, setPendingUndoAdditions] = useState<ExtendedSystemSignature[]>([]);
  const pendingAdditionMapRef = useRef<Record<string, { finalUntil: number; finalTimeoutId: number }>>({});

  // Use the provided deletion timing or fall back to the default
  const finalDuration = deletionTiming !== undefined ? deletionTiming : FINAL_DURATION_MS;

  const processAddedSignatures = useCallback(
    (added: ExtendedSystemSignature[]) => {
      if (!added.length) return;

      // If duration is 0, don't show pending state
      if (finalDuration === 0) {
        setSignatures(prev => [
          ...prev,
          ...added.map(sig => ({
            ...sig,
            pendingAddition: false,
          })),
        ]);
        return;
      }

      const now = Date.now();
      setSignatures(prev => [
        ...prev,
        ...added.map(sig => ({
          ...sig,
          pendingAddition: true,
          pendingUntil: now + finalDuration,
        })),
      ]);
      added.forEach(sig => {
        schedulePendingAdditionForSig(
          sig,
          finalDuration,
          setSignatures,
          pendingAdditionMapRef,
          setPendingUndoAdditions,
        );
      });
    },
    [setSignatures, finalDuration],
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
};
