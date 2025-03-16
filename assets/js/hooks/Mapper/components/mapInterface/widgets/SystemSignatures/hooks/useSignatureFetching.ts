import { useCallback } from 'react';
import { ExtendedSystemSignature, SystemSignature } from '@/hooks/Mapper/types';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { prepareUpdatePayload, getActualSigs, mergeLocalPending } from '../helpers';
import { UseFetchingParams } from './types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

export const useSignatureFetching = ({
  systemId,
  signaturesRef,
  setSignatures,
  pendingDeletionMapRef,
}: UseFetchingParams) => {
  const {
    data: { characters },
    outCommand,
  } = useMapRootState();

  const handleGetSignatures = useCallback(async () => {
    if (!systemId) {
      setSignatures([]);
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

    setSignatures(() => mergeLocalPending(pendingDeletionMapRef, extended));
  }, [characters, systemId, outCommand]);

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
    [systemId, outCommand, signaturesRef],
  );

  return {
    handleGetSignatures,
    handleUpdateSignatures,
  };
};
