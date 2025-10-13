import { useMapEventListener } from '@/hooks/Mapper/events';
import { parseSignatures } from '@/hooks/Mapper/helpers';
import { Commands, ExtendedSystemSignature, SignatureKind } from '@/hooks/Mapper/types';
import { useCallback, useEffect, useState } from 'react';
import useRefState from 'react-usestateref';

import { SETTINGS_KEYS } from '@/hooks/Mapper/constants/signatures.ts';
import { UseSystemSignaturesDataProps } from './types';
import { useSignatureFetching } from './useSignatureFetching';

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

      await handleUpdateSignatures(incomingSignatures, !lazyDeleteValue, false);

      const keepLazy = settings[SETTINGS_KEYS.KEEP_LAZY_DELETE] as boolean;
      if (lazyDeleteValue && !keepLazy) {
        onLazyDeleteChange?.(false);
      }
    },
    [settings, handleUpdateSignatures, onLazyDeleteChange],
  );

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
  }, [systemId]);

  return {
    signatures,
    selectedSignatures,
    setSelectedSignatures,
    handleDeleteSelected,
    handleSelectAll,
    handlePaste,
    hasUnsupportedLanguage,
  };
};
