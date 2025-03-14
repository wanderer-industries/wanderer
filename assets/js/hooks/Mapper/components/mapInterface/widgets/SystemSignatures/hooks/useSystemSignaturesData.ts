import { useCallback, useEffect, useState } from 'react';
import useRefState from 'react-usestateref';
import { useMapEventListener } from '@/hooks/Mapper/events';
import { Commands, ExtendedSystemSignature, SignatureKind, SystemSignature } from '@/hooks/Mapper/types';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { parseSignatures } from '@/hooks/Mapper/helpers';

import { getActualSigs, mergeLocalPendingAdditions } from '../helpers';
import { useSignatureFetching } from './useSignatureFetching';
import { usePendingAdditions } from './usePendingAdditions';
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

  const { localPendingDeletions, setLocalPendingDeletions, processRemovedSignatures, clearPendingDeletions } =
    usePendingDeletions({
      systemId,
      setSignatures,
      deletionTiming,
    });

  const { pendingUndoAdditions, setPendingUndoAdditions, processAddedSignatures, clearPendingAdditions } =
    usePendingAdditions({
      setSignatures,
      deletionTiming,
    });

  const { handleGetSignatures, handleUpdateSignatures } = useSignatureFetching({
    systemId,
    signaturesRef,
    setSignatures,
    localPendingDeletions,
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
        : signaturesRef.current.filter(sig => !sig.pendingDeletion && !sig.pendingAddition);

      const { added, updated, removed } = getActualSigs(currentNonPending, incomingSignatures, !lazyDeleteValue, true);

      if (added.length > 0) {
        processAddedSignatures(added);
      }

      if (removed.length > 0) {
        await processRemovedSignatures(removed, added, updated);
      } else {
        const resp = await outCommand({
          type: OutCommand.updateSignatures,
          data: {
            system_id: systemId,
            added,
            updated,
            removed: [],
          },
        });

        if (resp) {
          const finalSigs = (resp.signatures ?? []) as SystemSignature[];
          setSignatures(prev =>
            mergeLocalPendingAdditions(
              finalSigs.map(x => ({ ...x })),
              prev,
            ),
          );
        }
      }

      const keepLazy = settings[SETTINGS_KEYS.LAZY_DELETE_SIGNATURES] as boolean;
      if (lazyDeleteValue && !keepLazy) {
        onLazyDeleteChange?.(false);
      }
    },
    [
      settings,
      signaturesRef,
      processAddedSignatures,
      processRemovedSignatures,
      outCommand,
      systemId,
      setSignatures,
      onLazyDeleteChange,
    ],
  );

  const handleDeleteSelected = useCallback(async () => {
    if (!selectedSignatures.length) return;
    const selectedIds = selectedSignatures.map(s => s.eve_id);
    const finalList = signatures.filter(s => !selectedIds.includes(s.eve_id));

    await handleUpdateSignatures(finalList, false, true);
    setSelectedSignatures([]);
  }, [selectedSignatures, signatures, handleUpdateSignatures]);

  const handleSelectAll = useCallback(() => {
    setSelectedSignatures(signatures);
  }, [signatures]);

  const undoPending = useCallback(() => {
    clearPendingDeletions();
    clearPendingAdditions();
    setSignatures(prev =>
      prev.map(x => (x.pendingDeletion ? { ...x, pendingDeletion: false, pendingUntil: undefined } : x)),
    );

    if (pendingUndoAdditions.length) {
      pendingUndoAdditions.forEach(async sig => {
        await outCommand({
          type: OutCommand.updateSignatures,
          data: {
            system_id: systemId,
            added: [],
            updated: [],
            removed: [sig],
          },
        });
      });
      setSignatures(prev => prev.filter(x => !pendingUndoAdditions.some(u => u.eve_id === x.eve_id)));
      setPendingUndoAdditions([]);
    }
    setLocalPendingDeletions([]);
  }, [
    clearPendingDeletions,
    clearPendingAdditions,
    pendingUndoAdditions,
    setPendingUndoAdditions,
    setLocalPendingDeletions,
    setSignatures,
    outCommand,
    systemId,
  ]);

  useEffect(() => {
    const combined = [...localPendingDeletions, ...pendingUndoAdditions];
    onPendingChange?.(combined, undoPending);
  }, [localPendingDeletions, pendingUndoAdditions, onPendingChange, undoPending]);

  useMapEventListener(event => {
    if (event.name === Commands.signaturesUpdated && String(event.data) === String(systemId)) {
      handleGetSignatures();
      return true;
    }
  });

  useEffect(() => {
    if (!systemId) {
      setSignatures([]);
      return;
    }
    handleGetSignatures();
  }, [systemId, handleGetSignatures, setSignatures]);

  useEffect(() => {
    onCountChange?.(signatures.length);
  }, [signatures, onCountChange]);

  return {
    signatures,
    selectedSignatures,
    setSelectedSignatures,
    handleDeleteSelected,
    handleSelectAll,
    handlePaste,
  };
};
