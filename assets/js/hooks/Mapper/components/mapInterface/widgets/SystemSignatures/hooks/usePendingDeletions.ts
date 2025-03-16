import { useCallback, useRef, useEffect } from 'react';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { prepareUpdatePayload, scheduleLazyTimers } from '../helpers';
import { UsePendingDeletionParams } from './types';
import { FINAL_DURATION_MS } from '../constants';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { ExtendedSystemSignature } from '@/hooks/Mapper/types';

export function usePendingDeletions({
  systemId,
  setSignatures,
  deletionTiming,
  onPendingChange,
}: UsePendingDeletionParams) {
  const { outCommand } = useMapRootState();
  const pendingDeletionMapRef = useRef<Record<string, ExtendedSystemSignature>>({});

  // Use the provided deletion timing or fall back to the default
  const finalDuration = deletionTiming !== undefined ? deletionTiming : FINAL_DURATION_MS;

  const processRemovedSignatures = useCallback(
    async (
      removed: ExtendedSystemSignature[],
      added: ExtendedSystemSignature[],
      updated: ExtendedSystemSignature[],
    ) => {
      if (!removed.length) return;

      // If deletion timing is 0, immediately delete without pending state
      if (finalDuration === 0) {
        await outCommand({
          type: OutCommand.updateSignatures,
          data: prepareUpdatePayload(systemId, added, updated, removed),
        });
        return;
      }

      const now = Date.now();
      const processedRemoved = removed.map(r => ({
        ...r,
        pendingDeletion: true,
        pendingUntil: now + finalDuration,
      }));
      pendingDeletionMapRef.current = {
        ...pendingDeletionMapRef.current,
        ...processedRemoved.reduce((acc: any, sig) => {
          acc[sig.eve_id] = sig;
          return acc;
        }, {}),
      };

      onPendingChange?.(pendingDeletionMapRef, clearPendingDeletions);

      setSignatures(prev =>
        prev.map(sig => {
          if (processedRemoved.find(r => r.eve_id === sig.eve_id)) {
            return { ...sig, pendingDeletion: true, pendingUntil: now + finalDuration };
          }
          return sig;
        }),
      );

      scheduleLazyTimers(
        processedRemoved,
        pendingDeletionMapRef,
        async sig => {
          await outCommand({
            type: OutCommand.updateSignatures,
            data: prepareUpdatePayload(systemId, [], [], [sig]),
          });
          delete pendingDeletionMapRef.current[sig.eve_id];
          setSignatures(prev => prev.filter(x => x.eve_id !== sig.eve_id));
          onPendingChange?.(pendingDeletionMapRef, clearPendingDeletions);
        },
        finalDuration,
      );
    },
    [systemId, outCommand, finalDuration],
  );

  const clearPendingDeletions = useCallback(() => {
    Object.values(pendingDeletionMapRef.current).forEach(({ finalTimeoutId }) => {
      clearTimeout(finalTimeoutId);
    });
    pendingDeletionMapRef.current = {};
    setSignatures(prev => prev.map(x => (x.pendingDeletion ? { ...x, pendingDeletion: false } : x)));
    onPendingChange?.(pendingDeletionMapRef, clearPendingDeletions);
  }, []);

  return {
    pendingDeletionMapRef,
    processRemovedSignatures,
    clearPendingDeletions,
  };
}
