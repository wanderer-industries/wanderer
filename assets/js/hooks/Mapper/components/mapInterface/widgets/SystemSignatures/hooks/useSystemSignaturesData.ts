import { useCallback, useEffect, useState } from 'react';
import useRefState from 'react-usestateref';
import { useMapEventListener } from '@/hooks/Mapper/events';
import { Commands, ExtendedSystemSignature, SignatureKind } from '@/hooks/Mapper/types';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { parseSignatures } from '@/hooks/Mapper/helpers';

import { getActualSigs } from '../helpers';
import { useSignatureFetching } from './useSignatureFetching';
import { usePendingDeletions } from './usePendingDeletions';
import { UseSystemSignaturesDataProps } from './types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { SETTINGS_KEYS } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/constants.ts';

export const useSystemSignaturesData = ({
  systemId,
  settings,
  onCountChange,
  onPendingChange,
  onLazyDeleteChange,
  deletionTiming,
}: UseSystemSignaturesDataProps) => {
  const { outCommand } = useMapRootState();
  const [signatures, setSignatures, signaturesRef] = useRefState<ExtendedSystemSignature[]>([]);
  const [selectedSignatures, setSelectedSignatures] = useState<ExtendedSystemSignature[]>([]);

  const { pendingDeletionMapRef, processRemovedSignatures, clearPendingDeletions } = usePendingDeletions({
    systemId,
    setSignatures,
    deletionTiming,
    onPendingChange,
  });

  const { handleGetSignatures, handleUpdateSignatures } = useSignatureFetching({
    systemId,
    signaturesRef,
    setSignatures,
    pendingDeletionMapRef,
  });

  const handlePaste = useCallback(
    async (clipboardString: string) => {
      const lazyDeleteValue = settings[SETTINGS_KEYS.LAZY_DELETE_SIGNATURES] as boolean;

      const incomingSignatures = parseSignatures(
        clipboardString,
        Object.keys(settings).filter(skey => skey in SignatureKind),
      ) as ExtendedSystemSignature[];

      const currentNonPending = lazyDeleteValue
        ? signaturesRef.current.filter(sig => !sig.pendingDeletion)
        : signaturesRef.current.filter(sig => !sig.pendingDeletion || !sig.pendingAddition);

      const { added, updated, removed } = getActualSigs(currentNonPending, incomingSignatures, !lazyDeleteValue, true);

      if (removed.length > 0) {
        await processRemovedSignatures(removed, added, updated);
      }

      if (updated.length !== 0 || added.length !== 0) {
        await outCommand({
          type: OutCommand.updateSignatures,
          data: {
            system_id: systemId,
            added,
            updated,
            removed: [],
          },
        });
      }

      const keepLazy = settings[SETTINGS_KEYS.KEEP_LAZY_DELETE] as boolean;
      if (lazyDeleteValue && !keepLazy) {
        onLazyDeleteChange?.(false);
      }
    },
    [settings, signaturesRef, processRemovedSignatures, outCommand, systemId, onLazyDeleteChange],
  );

  const handleDeleteSelected = useCallback(async () => {
    if (!selectedSignatures.length) return;
    const selectedIds = selectedSignatures.map(s => s.eve_id);
    const finalList = signatures.filter(s => !selectedIds.includes(s.eve_id));

    await handleUpdateSignatures(finalList, false, true);
    setSelectedSignatures([]);
  }, [selectedSignatures, signatures]);

  const handleSelectAll = useCallback(() => {
    setSelectedSignatures(signatures);
  }, [signatures]);

  const undoPending = useCallback(() => {
    clearPendingDeletions();
  }, [clearPendingDeletions]);

  useMapEventListener(event => {
    if (event.name === Commands.signaturesUpdated && String(event.data) === String(systemId)) {
      handleGetSignatures();
      return true;
    }
  });

  useEffect(() => {
    if (!systemId) {
      setSignatures([]);
      undoPending();
      return;
    }
    handleGetSignatures();
  }, [systemId]);

  useEffect(() => {
    onCountChange?.(signatures.length);
  }, [signatures]);

  return {
    signatures,
    selectedSignatures,
    setSelectedSignatures,
    handleDeleteSelected,
    handleSelectAll,
    handlePaste,
  };
};
