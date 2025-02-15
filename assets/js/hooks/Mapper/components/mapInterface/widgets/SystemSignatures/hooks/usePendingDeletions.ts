import { useState, useCallback } from 'react';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { ExtendedSystemSignature, prepareUpdatePayload, scheduleLazyDeletionTimers } from '../helpers';
import { UsePendingDeletionParams } from './types';
import { FINAL_DURATION_MS } from '../constants';

export function usePendingDeletions({ systemId, outCommand, setSignatures }: UsePendingDeletionParams) {
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
      const processedRemoved = removed.map(r => ({ ...r, pendingDeletion: true, pendingAddition: false }));
      setLocalPendingDeletions(prev => [...prev, ...processedRemoved]);

      const resp = await outCommand({
        type: OutCommand.updateSignatures,
        data: prepareUpdatePayload(systemId, added, updated, []),
      });
      const updatedFromServer = resp.signatures as ExtendedSystemSignature[];

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

      const now = Date.now();
      const updatedWithRemoval = updatedFromServer.map(sig => {
        const wasRemoved = processedRemoved.find(r => r.eve_id === sig.eve_id);
        return wasRemoved ? { ...sig, pendingDeletion: true, pendingUntil: now + FINAL_DURATION_MS } : sig;
      });

      const extras = processedRemoved
        .map(r => ({ ...r, pendingDeletion: true, pendingUntil: now + FINAL_DURATION_MS }))
        .filter(r => !updatedWithRemoval.some(m => m.eve_id === r.eve_id));

      setSignatures([...updatedWithRemoval, ...extras]);
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
