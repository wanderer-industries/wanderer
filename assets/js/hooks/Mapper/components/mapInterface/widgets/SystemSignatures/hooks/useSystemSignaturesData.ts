import { useCallback, useEffect, useState } from 'react';
import useRefState from 'react-usestateref';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useMapEventListener } from '@/hooks/Mapper/events';
import { Commands, SystemSignature } from '@/hooks/Mapper/types';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { parseSignatures } from '@/hooks/Mapper/helpers';
import {
  KEEP_LAZY_DELETE_SETTING,
  LAZY_DELETE_SIGNATURES_SETTING,
} from '@/hooks/Mapper/components/mapInterface/widgets';
import { ExtendedSystemSignature, getActualSigs } from '../helpers';
import { useSignatureFetching } from './useSignatureFetching';
import { usePendingAdditions } from './usePendingAdditions';
import { usePendingDeletions } from './usePendingDeletions';
import { UseSystemSignaturesDataProps } from './types';
import { TIME_ONE_DAY, TIME_ONE_WEEK } from '../constants';
import { SignatureGroup } from '@/hooks/Mapper/types';

export function useSystemSignaturesData({
  systemId,
  settings,
  onCountChange,
  onPendingChange,
  onLazyDeleteChange,
}: UseSystemSignaturesDataProps) {
  const { outCommand } = useMapRootState();

  const [signatures, setSignatures, signaturesRef] = useRefState<ExtendedSystemSignature[]>([]);

  const [selectedSignatures, setSelectedSignatures] = useState<ExtendedSystemSignature[]>([]);

  const { localPendingDeletions, setLocalPendingDeletions, processRemovedSignatures, clearPendingDeletions } =
    usePendingDeletions({
      systemId,
      outCommand,
      setSignatures,
    });

  const { pendingUndoAdditions, setPendingUndoAdditions, processAddedSignatures, clearPendingAdditions } =
    usePendingAdditions({
      setSignatures,
    });

  const { handleGetSignatures, handleUpdateSignatures } = useSignatureFetching({
    systemId,
    signaturesRef,
    setSignatures,
    outCommand,
    localPendingDeletions,
  });

  const handlePaste = useCallback(
    async (clipboardString: string) => {
      const lazyDeleteValue = settings.find(s => s.key === LAZY_DELETE_SIGNATURES_SETTING)?.value ?? false;

      const incomingSignatures = parseSignatures(
        clipboardString,
        settings.map(s => s.key),
      ) as ExtendedSystemSignature[];

      const current = signaturesRef.current;
      const currentNonPending = lazyDeleteValue
        ? current.filter(sig => !sig.pendingDeletion)
        : current.filter(sig => !sig.pendingDeletion && !sig.pendingAddition);

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
        const finalSigs = (resp.signatures ?? []) as SystemSignature[];
        setSignatures(finalSigs.map(x => ({ ...x })));
      }

      const keepLazy = settings.find(s => s.key === KEEP_LAZY_DELETE_SETTING)?.value ?? false;
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
      prev.map(x => {
        if (x.pendingDeletion) {
          return { ...x, pendingDeletion: false, pendingUntil: undefined };
        }
        return x;
      }),
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

  useEffect(() => {
    if (!systemId) return;
    const now = Date.now();
    const oldOnes = signaturesRef.current.filter(sig => {
      if (!sig.inserted_at) return false;
      const inserted = new Date(sig.inserted_at).getTime();
      const threshold = sig.group === SignatureGroup.Wormhole ? TIME_ONE_DAY : TIME_ONE_WEEK;
      return now - inserted > threshold;
    });
    if (oldOnes.length) {
      const remain = signaturesRef.current.filter(x => !oldOnes.includes(x));
      handleUpdateSignatures(remain, false, true);
    }
  }, [systemId, handleUpdateSignatures, signaturesRef]);

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
}
