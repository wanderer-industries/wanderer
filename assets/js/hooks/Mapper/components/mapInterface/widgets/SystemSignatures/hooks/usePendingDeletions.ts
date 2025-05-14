import { useCallback, useRef } from 'react';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { prepareUpdatePayload } from '../helpers';
import { UsePendingDeletionParams } from './types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { ExtendedSystemSignature } from '@/hooks/Mapper/types';

export function usePendingDeletions({
  systemId,
  setSignatures,
  onPendingChange,
}: Omit<UsePendingDeletionParams, 'deletionTiming'>) {
  const { outCommand } = useMapRootState();
  const pendingDeletionMapRef = useRef<Record<string, ExtendedSystemSignature>>({});

  const processRemovedSignatures = useCallback(
    async (
      removed: ExtendedSystemSignature[],
      added: ExtendedSystemSignature[],
      updated: ExtendedSystemSignature[],
    ) => {
      if (!removed.length) return;
      await outCommand({
        type: OutCommand.updateSignatures,
        data: prepareUpdatePayload(systemId, added, updated, removed),
      });
    },
    [systemId, outCommand],
  );

  const clearPendingDeletions = useCallback(() => {
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
