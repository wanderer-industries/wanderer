import { useMapEventListener } from '@/hooks/Mapper/events';
import { parseSignatures } from '@/hooks/Mapper/helpers';
import { Commands, ExtendedSystemSignature, SignatureKind } from '@/hooks/Mapper/types';
import { useCallback, useEffect, useState } from 'react';
import useRefState from 'react-usestateref';

import { SETTINGS_KEYS } from '@/hooks/Mapper/constants/signatures.ts';
import { SIGNATURE_GLOWINGROWS_TIMEOUTS } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/constants.ts';
import { UseSystemSignaturesDataProps } from './types';
import { useSignatureFetching } from './useSignatureFetching';

type GlowingRowInfo = {
  isNew: boolean;
};
const DEFAULT_GLOWINGROWS_TIMEOUT = 1000;

const checkIfSignatureIsBrandNew = (sigId: string, existingSignatures: ExtendedSystemSignature[]): boolean => {
  const existing = existingSignatures.find(s => s.eve_id === sigId);
  if (!existing) return true;
  if (!existing.updated_at) return true;
  if (!existing.inserted_at) return true;
  const insertedTime = new Date(existing.inserted_at).getTime();
  const updatedTime = new Date(existing.updated_at).getTime();
  const timeDifference = Math.abs(insertedTime - updatedTime);
  return timeDifference < 50;
};

const extractGlowingRowsTimingKey = (glowingRowsValue: unknown): unknown => {
  if (glowingRowsValue && typeof glowingRowsValue === 'object' && 'value' in glowingRowsValue) {
    return (glowingRowsValue as Record<string, unknown>).value;
  }
  return glowingRowsValue;
};

export const useSystemSignaturesData = ({
  systemId,
  settings,
  onLazyDeleteChange,
}: Omit<UseSystemSignaturesDataProps, 'deletionTiming'> & {
  onSignatureDeleted?: (deletedSignatures: ExtendedSystemSignature[]) => void;
}) => {
  const [signatures, setSignatures, signaturesRef] = useRefState<ExtendedSystemSignature[]>([]);
  const [selectedSignatures, setSelectedSignatures] = useState<ExtendedSystemSignature[]>([]);
  const [hasUnsupportedLanguage, setHasUnsupportedLanguage] = useState<boolean>(false);

  const [glowingRows, setGlowingRows] = useState<Map<string, GlowingRowInfo>>(new Map());

  const { handleGetSignatures, handleUpdateSignatures } = useSignatureFetching({
    systemId,
    settings,
    signaturesRef,
    setSignatures,
  });

  const handlePaste = useCallback(
    async (clipboardString: string) => {
      const lazyDeleteValue = settings[SETTINGS_KEYS.LAZY_DELETE_SIGNATURES] as boolean;

      // Parse the incoming signatures
      const incomingSignatures = parseSignatures(
        clipboardString,
        Object.keys(settings).filter(skye => skye in SignatureKind),
      ) as ExtendedSystemSignature[];
      if (incomingSignatures.length === 0) {
        return;
      }

      setGlowingRows(current => {
        const newGlowing = new Map(current);
        incomingSignatures.forEach(sig => {
          const alreadyGlowing = current.get(sig.eve_id);
          if (alreadyGlowing && alreadyGlowing.isNew) {
            newGlowing.set(sig.eve_id, { isNew: true });
            return;
          }
          const isBrandNew = checkIfSignatureIsBrandNew(sig.eve_id, signaturesRef.current);
          newGlowing.set(sig.eve_id, { isNew: isBrandNew });
        });
        return newGlowing;
      });
      // Check if any signatures might be using unsupported languages
      // This is a basic heuristic: if we have signatures where the original group wasn't mapped
      const clipboardRows = clipboardString.split('\n').filter(row => row.trim() !== '');
      const detectedSignatureCount = clipboardRows.filter(row => row.match(/^[A-Z]{3}-\d{3}/)).length;

      // If we detected valid IDs but got fewer parsed signatures, we might have language issue
      if (detectedSignatureCount > 0 && incomingSignatures.length < detectedSignatureCount) {
        setHasUnsupportedLanguage(true);
      } else {
        setHasUnsupportedLanguage(false);
      }

      await handleUpdateSignatures(incomingSignatures, !lazyDeleteValue, false);

      const keepLazy = settings[SETTINGS_KEYS.KEEP_LAZY_DELETE] as boolean;
      if (lazyDeleteValue && !keepLazy) {
        onLazyDeleteChange?.(false);
      }
    },
    [settings, handleUpdateSignatures, onLazyDeleteChange, signaturesRef],
  );

  useEffect(() => {
    if (glowingRows.size === 0) return;

    const glowingRowsValue = settings[SETTINGS_KEYS.GLOWINGROWS_TIMING];
    const timingKey = extractGlowingRowsTimingKey(glowingRowsValue);

    const glowingRowsTimeoutDuration =
      SIGNATURE_GLOWINGROWS_TIMEOUTS[timingKey as keyof typeof SIGNATURE_GLOWINGROWS_TIMEOUTS] ??
      DEFAULT_GLOWINGROWS_TIMEOUT;

    const glowingRowsTimer1 = setTimeout(() => {
      setGlowingRows(new Map());
    }, glowingRowsTimeoutDuration);

    return () => clearTimeout(glowingRowsTimer1);
  }, [glowingRows, settings, systemId]);

  const handleDeleteSelected = useCallback(async () => {
    if (!selectedSignatures.length) return;

    const selectedIds = selectedSignatures.map(s => s.eve_id);
    const finalList = signatures.filter(s => !selectedIds.includes(s.eve_id));

    setSelectedSignatures([]);

    await handleUpdateSignatures(finalList, false, true);
  }, [handleUpdateSignatures, selectedSignatures, signatures]);

  const handleSelectAll = useCallback(() => {
    setSelectedSignatures(signatures);
  }, [signatures]);

  useMapEventListener(event => {
    if (event.name === Commands.signaturesUpdated && String(event.data) === String(systemId)) {
      handleGetSignatures().then(() => {});
      return true;
    }
  });

  useEffect(() => {
    if (!systemId) {
      setSignatures([]);
      return;
    }
    void handleGetSignatures();
  }, [systemId, handleGetSignatures, setSignatures]);

  return {
    signatures,
    selectedSignatures,
    setSelectedSignatures,
    handleDeleteSelected,
    handleSelectAll,
    handlePaste,
    hasUnsupportedLanguage,
    glowingRows,
  };
};
