import { useState, useCallback } from 'react';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { ExtendedSystemSignature, prepareUpdatePayload, scheduleLazyDeletionTimers } from '../helpers';
import { UsePendingDeletionParams } from './types';
import { FINAL_DURATION_MS } from '../constants';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

export function usePendingDeletions({ systemId, setSignatures }: UsePendingDeletionParams) {
  const { outCommand } = useMapRootState();
  const [localPendingDeletions, setLocalPendingDeletions] = useState<ExtendedSystemSignature[]>([]);
  const [pendingDeletionMap, setPendingDeletionMap] = useState<
    Record<string, { finalUntil: number; finalTimeoutId: number }>
  >({});

  const processRemovedSignatures = useCallback(
    async (
      removed: ExtendedSystemSignature[],
      added: ExtendedSystemSignature[],
      updated: ExtendedSystemSignature[],
    ) => {
      if (!removed.length) return;
      const now = Date.now();
      const processedRemoved = removed.map(r => ({
        ...r,
        pendingDeletion: true,
        pendingAddition: false,
        pendingUntil: now + FINAL_DURATION_MS,
      }));
      setLocalPendingDeletions(prev => [...prev, ...processedRemoved]);

      outCommand({
        type: OutCommand.updateSignatures,
        data: prepareUpdatePayload(systemId, added, updated, []),
      });

      setSignatures(prev =>
        prev.map(sig => {
          if (processedRemoved.find(r => r.eve_id === sig.eve_id)) {
            return { ...sig, pendingDeletion: true, pendingUntil: now + FINAL_DURATION_MS };
          }
          return sig;
        }),
      );

      scheduleLazyDeletionTimers(
        processedRemoved,
        setPendingDeletionMap,
        async sig => {
          await outCommand({
            type: OutCommand.updateSignatures,
            data: prepareUpdatePayload(systemId, [], [], [sig]),
          });
          setLocalPendingDeletions(prev => prev.filter(x => x.eve_id !== sig.eve_id));
          setSignatures(prev => prev.filter(x => x.eve_id !== sig.eve_id));
        },
        FINAL_DURATION_MS,
      );
    },
    [systemId, outCommand, setSignatures],
  );

  const clearPendingDeletions = useCallback(() => {
    Object.values(pendingDeletionMap).forEach(({ finalTimeoutId }) => clearTimeout(finalTimeoutId));
    setPendingDeletionMap({});
    setSignatures(prev =>
      prev.map(x => (x.pendingDeletion ? { ...x, pendingDeletion: false, pendingUntil: undefined } : x)),
    );
    setLocalPendingDeletions([]);
  }, [pendingDeletionMap, setSignatures]);

  return {
    localPendingDeletions,
    setLocalPendingDeletions,
    pendingDeletionMap,
    setPendingDeletionMap,
    processRemovedSignatures,
    clearPendingDeletions,
  };
}
