import { useMapEventListener } from '@/hooks/Mapper/events';
import { parseSignatures } from '@/hooks/Mapper/helpers';
import { Commands, ExtendedSystemSignature, SignatureKind } from '@/hooks/Mapper/types';
import { useCallback, useEffect, useState, useRef } from 'react';
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
  return !existing;
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

  const timeoutsRef = useRef<Record<string, NodeJS.Timeout>>({});

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

      const currentPasteIds = incomingSignatures.map(sig => sig.eve_id);
      const glowingRowsValue = settings[SETTINGS_KEYS.GLOWINGROWS_TIMING];
      const timingKey = extractGlowingRowsTimingKey(glowingRowsValue);
      const glowingRowsTimeoutDuration =
        SIGNATURE_GLOWINGROWS_TIMEOUTS[timingKey as keyof typeof SIGNATURE_GLOWINGROWS_TIMEOUTS] ??
        DEFAULT_GLOWINGROWS_TIMEOUT;

      setGlowingRows(current => {
        const newGlowing = new Map(current);

        incomingSignatures.forEach((sig, index) => {
          const alreadyGlowing = current.get(sig.eve_id);
          let isBrandNew: boolean;
          if (alreadyGlowing) {
            isBrandNew = alreadyGlowing.isNew;
          } else {
            const isDuplicateInThisPaste = currentPasteIds.indexOf(sig.eve_id) < index;
            isBrandNew = !isDuplicateInThisPaste && checkIfSignatureIsBrandNew(sig.eve_id, signaturesRef.current);
          }

          newGlowing.set(sig.eve_id, { isNew: isBrandNew });
          if (timeoutsRef.current[sig.eve_id]) {
            clearTimeout(timeoutsRef.current[sig.eve_id]);
          }

          timeoutsRef.current[sig.eve_id] = setTimeout(() => {
            setGlowingRows(prev => {
              const updatedMap = new Map(prev);
              updatedMap.delete(sig.eve_id);
              return updatedMap;
            });
            delete timeoutsRef.current[sig.eve_id];
          }, glowingRowsTimeoutDuration);
        });

        return newGlowing;
      });

      const clipboardRows = clipboardString.split('\n').filter(row => row.trim() !== '');
      const detectedSignatureCount = clipboardRows.filter(row => row.match(/^[A-Z]{3}-\d{3}/)).length;

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
    const currentTimeouts = timeoutsRef.current;
    return () => {
      if (currentTimeouts) {
        Object.values(currentTimeouts).forEach(clearTimeout);
      }
    };
  }, []);

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
