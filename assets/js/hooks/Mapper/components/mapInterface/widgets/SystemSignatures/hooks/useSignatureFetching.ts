import { useCallback } from 'react';
import { SystemSignature } from '@/hooks/Mapper/types';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { ExtendedSystemSignature, prepareUpdatePayload, getActualSigs } from '../helpers';
import { UseFetchingParams } from './types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

export function useSignatureFetching({
  systemId,
  signaturesRef,
  setSignatures,
  localPendingDeletions,
}: UseFetchingParams) {
  const {
    data: { characters },
    outCommand,
  } = useMapRootState();

  const handleGetSignatures = useCallback(async () => {
    if (!systemId) {
      setSignatures([]);
      return;
    }
    if (localPendingDeletions.length) {
      return;
    }
    const resp = await outCommand({
      type: OutCommand.getSignatures,
      data: { system_id: systemId },
    });
    const serverSigs = (resp.signatures ?? []) as SystemSignature[];
    const extended = serverSigs.map(s => ({
      ...s,
      character_name: characters.find(c => c.eve_id === s.character_eve_id)?.name,
    })) as ExtendedSystemSignature[];
    setSignatures(extended);
  }, [characters, systemId, localPendingDeletions, outCommand, setSignatures]);

  const handleUpdateSignatures = useCallback(
    async (newList: ExtendedSystemSignature[], updateOnly: boolean, skipUpdateUntouched?: boolean) => {
      const { added, updated, removed } = getActualSigs(
        signaturesRef.current,
        newList,
        updateOnly,
        skipUpdateUntouched,
      );

      await outCommand({
        type: OutCommand.updateSignatures,
        data: prepareUpdatePayload(systemId, added, updated, removed),
      });
    },
    [systemId, signaturesRef, outCommand],
  );

  return {
    handleGetSignatures,
    handleUpdateSignatures,
  };
}
