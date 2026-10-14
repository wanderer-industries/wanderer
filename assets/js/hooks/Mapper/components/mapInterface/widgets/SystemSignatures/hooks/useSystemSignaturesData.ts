import { useMapEventListener } from '@/hooks/Mapper/events';
import { parseSignatures } from '@/hooks/Mapper/helpers';
import { Commands, ExtendedSystemSignature, SignatureKind } from '@/hooks/Mapper/types';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import useRefState from 'react-usestateref';

import { SETTINGS_KEYS } from '@/hooks/Mapper/constants/signatures.ts';
import { getGlowingRowsTimeoutMs } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/constants.ts';
import { getSignatureUpdateGlows } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/helpers';
import { GlowingRowInfo, UseSystemSignaturesDataProps } from './types';
import { useSignatureFetching } from './useSignatureFetching';

const SIGNATURE_KINDS = new Set<string>(Object.values(SignatureKind));

const deduplicateSignatures = (signatures: ExtendedSystemSignature[]): ExtendedSystemSignature[] => {
  const signaturesById = new Map<string, ExtendedSystemSignature>();
  signatures.forEach(signature => signaturesById.set(signature.eve_id, signature));
  return Array.from(signaturesById.values());
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

  const [pendingGlowingRows, setPendingGlowingRows] = useState<Map<string, GlowingRowInfo>>(() => new Map());
  const [glowingRows, setGlowingRows, glowingRowsRef] = useRefState<Map<string, GlowingRowInfo>>(new Map());
  const glowingRowTimersRef = useRef<Map<string, ReturnType<typeof setTimeout>>>(new Map());
  const loadedSystemIdRef = useRef<string | null>(null);

  const glowingRowsTimeout = useMemo(() => getGlowingRowsTimeoutMs(settings), [settings]);

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
      const parsedSignatures = parseSignatures(
        clipboardString,
        Object.keys(settings).filter(key => SIGNATURE_KINDS.has(key)),
      ) as ExtendedSystemSignature[];
      const incomingSignatures = deduplicateSignatures(parsedSignatures);
      if (incomingSignatures.length === 0) {
        return;
      }

      const existingSignatureIds = new Set(signaturesRef.current.map(signature => signature.eve_id));
      setPendingGlowingRows(current => {
        const next = new Map(current);
        incomingSignatures.forEach(signature => {
          const existingPendingGlow = current.get(signature.eve_id);
          const existingActiveGlow = glowingRowsRef.current.get(signature.eve_id);
          if (existingPendingGlow?.systemId === systemId || existingActiveGlow?.systemId === systemId) {
            return;
          }

          next.set(signature.eve_id, {
            isNew: !existingSignatureIds.has(signature.eve_id),
            systemId,
          });
        });
        return next;
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
    [settings, handleUpdateSignatures, onLazyDeleteChange, signaturesRef, systemId, glowingRowsRef],
  );

  useEffect(() => {
    const glowingRowTimers = glowingRowTimersRef.current;
    glowingRowTimers.forEach(timer => clearTimeout(timer));
    glowingRowTimers.clear();
    setPendingGlowingRows(new Map());
    setGlowingRows(new Map());

    return () => {
      glowingRowTimers.forEach(timer => clearTimeout(timer));
      glowingRowTimers.clear();
    };
  }, [setGlowingRows, systemId]);

  useEffect(() => {
    if (pendingGlowingRows.size === 0) return;

    const visibleSignatureIds = new Set(signatures.map(signature => signature.eve_id));
    const rowsReadyToGlow = Array.from(pendingGlowingRows.entries()).filter(([signatureId, glowInfo]) => {
      return glowInfo.systemId === systemId && visibleSignatureIds.has(signatureId);
    });

    if (rowsReadyToGlow.length === 0) return;

    setPendingGlowingRows(current => {
      const next = new Map(current);
      rowsReadyToGlow.forEach(([signatureId]) => next.delete(signatureId));
      return next;
    });

    if (glowingRowsTimeout === 0) return;

    setGlowingRows(current => {
      const next = new Map(current);
      rowsReadyToGlow.forEach(([signatureId, glowInfo]) => next.set(signatureId, glowInfo));
      return next;
    });

    rowsReadyToGlow.forEach(([signatureId, glowInfo]) => {
      const currentTimer = glowingRowTimersRef.current.get(signatureId);
      if (currentTimer) {
        clearTimeout(currentTimer);
      }

      const timer = setTimeout(() => {
        glowingRowTimersRef.current.delete(signatureId);
        setGlowingRows(current => {
          const activeGlow = current.get(signatureId);
          if (activeGlow?.systemId !== glowInfo.systemId) {
            return current;
          }

          const next = new Map(current);
          next.delete(signatureId);
          return next;
        });
      }, glowingRowsTimeout);
      glowingRowTimersRef.current.set(signatureId, timer);
    });
  }, [glowingRowsTimeout, pendingGlowingRows, setGlowingRows, signatures, systemId]);

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
      const previousSignatures = signaturesRef.current;
      const hadLoadedSignatures = loadedSystemIdRef.current === systemId;

      void handleGetSignatures().then(nextSignatures => {
        if (!nextSignatures) {
          return;
        }

        loadedSystemIdRef.current = systemId;
        if (!hadLoadedSignatures) {
          return;
        }

        const remotelyGlowingRows = getSignatureUpdateGlows(previousSignatures, nextSignatures, systemId);
        if (remotelyGlowingRows.size === 0) {
          return;
        }

        setPendingGlowingRows(current => {
          const next = new Map(current);
          remotelyGlowingRows.forEach((glowInfo, signatureId) => {
            const localGlow = current.get(signatureId);
            const activeGlow = glowingRowsRef.current.get(signatureId);
            if (localGlow?.systemId === systemId || activeGlow?.systemId === systemId) {
              return;
            }

            next.set(signatureId, glowInfo);
          });
          return next;
        });
      });
      return true;
    }
  });

  useEffect(() => {
    loadedSystemIdRef.current = null;
    setSelectedSignatures([]);
    setSignatures([]);
    if (!systemId) {
      return;
    }
    void handleGetSignatures().then(nextSignatures => {
      if (nextSignatures) {
        loadedSystemIdRef.current = systemId;
      }
    });
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
