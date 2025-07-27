import { useMapEventListener } from '@/hooks/Mapper/events';
import { parseSignatures } from '@/hooks/Mapper/helpers';
import { Commands, ExtendedSystemSignature, SignatureKind } from '@/hooks/Mapper/types';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { useCallback, useEffect, useState } from 'react';
import useRefState from 'react-usestateref';

import { getDeletionTimeoutMs } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/constants.ts';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { getActualSigs } from '../helpers';
import { UseSystemSignaturesDataProps } from './types';
import { usePendingDeletions } from './usePendingDeletions';
import { useSignatureFetching } from './useSignatureFetching';
import { SETTINGS_KEYS } from '@/hooks/Mapper/constants/signatures.ts';

export const useSystemSignaturesData = ({
  systemId,
  settings,
  onCountChange,
  onPendingChange,
  onLazyDeleteChange,
  onSignatureDeleted,
}: Omit<UseSystemSignaturesDataProps, 'deletionTiming'> & {
  onSignatureDeleted?: (deletedSignatures: ExtendedSystemSignature[]) => void;
}) => {
  const { outCommand } = useMapRootState();
  const [signatures, setSignatures, signaturesRef] = useRefState<ExtendedSystemSignature[]>([]);
  const [selectedSignatures, setSelectedSignatures] = useState<ExtendedSystemSignature[]>([]);
  const [hasUnsupportedLanguage, setHasUnsupportedLanguage] = useState<boolean>(false);

  const { pendingDeletionMapRef, processRemovedSignatures, clearPendingDeletions } = usePendingDeletions({
    systemId,
    setSignatures,
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

      // Parse the incoming signatures
      const incomingSignatures = parseSignatures(
        clipboardString,
        Object.keys(settings).filter(skey => skey in SignatureKind),
      ) as ExtendedSystemSignature[];

      if (incomingSignatures.length === 0) {
        return;
      }

      // Check if any signatures might be using unsupported languages
      // This is a basic heuristic: if we have signatures where the original group wasn't mapped
      const clipboardRows = clipboardString.split('\n').filter(row => row.trim() !== '');
      const detectedSignatureCount = clipboardRows.filter(row => row.match(/^[A-Z]{3}-\d{3}/)).length;

      // If we detected valid IDs but got fewer parsed signatures, we might have language issues
      if (detectedSignatureCount > 0 && incomingSignatures.length < detectedSignatureCount) {
        setHasUnsupportedLanguage(true);
      } else {
        setHasUnsupportedLanguage(false);
      }

      const currentNonPending = lazyDeleteValue
        ? signaturesRef.current.filter(sig => !sig.pendingDeletion)
        : signaturesRef.current.filter(sig => !sig.pendingDeletion || !sig.pendingAddition);

      const { added, updated, removed } = getActualSigs(currentNonPending, incomingSignatures, !lazyDeleteValue, false);

      if (removed.length > 0) {
        await processRemovedSignatures(removed, added, updated);

        // Show pending deletions if lazy deletion is enabled
        // The deletion timing controls how long the countdown lasts, not whether lazy delete is active
        if (onSignatureDeleted && lazyDeleteValue) {
          onSignatureDeleted(removed);
        }
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
    [settings, signaturesRef, processRemovedSignatures, outCommand, systemId, onLazyDeleteChange, onSignatureDeleted],
  );

  const handleDeleteSelected = useCallback(async () => {
    if (!selectedSignatures.length) return;

    const selectedIds = selectedSignatures.map(s => s.eve_id);
    const finalList = signatures.filter(s => !selectedIds.includes(s.eve_id));

    // IMPORTANT: Send deletion to server BEFORE updating local state
    // Otherwise signaturesRef.current will be updated and getActualSigs won't detect removals
    await handleUpdateSignatures(finalList, false, true);

    // Update local state after server call
    setSignatures(finalList);
    setSelectedSignatures([]);
  }, [handleUpdateSignatures, selectedSignatures, signatures, setSignatures]);

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
    signatures: signatures.filter(sig => !sig.deleted),
    selectedSignatures,
    setSelectedSignatures,
    handleDeleteSelected,
    handleSelectAll,
    handlePaste,
    hasUnsupportedLanguage,
  };
};
