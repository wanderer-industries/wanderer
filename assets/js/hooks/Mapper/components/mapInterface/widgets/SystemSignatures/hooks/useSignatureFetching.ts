import { useCallback } from 'react';
import { SystemSignature } from '@/hooks/Mapper/types';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { ExtendedSystemSignature, prepareUpdatePayload, getActualSigs } from '../helpers';
import { UseFetchingParams } from './types';

export function useSignatureFetching({
  systemId,
  signaturesRef,
  setSignatures,
  outCommand,
  localPendingDeletions,
}: UseFetchingParams) {
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
    const extended = serverSigs.map(x => ({ ...x })) as ExtendedSystemSignature[];
    setSignatures(extended);
  }, [systemId, localPendingDeletions, outCommand, setSignatures]);

  const handleUpdateSignatures = useCallback(
    async (newList: ExtendedSystemSignature[], updateOnly: boolean, skipUpdateUntouched?: boolean) => {
      const { added, updated, removed } = getActualSigs(
        signaturesRef.current,
        newList,
        updateOnly,
        skipUpdateUntouched,
      );

      const resp = await outCommand({
        type: OutCommand.updateSignatures,
        data: prepareUpdatePayload(systemId, added, updated, removed),
      });
      const final = (resp.signatures ?? []) as SystemSignature[];
      setSignatures(final.map(x => ({ ...x })) as ExtendedSystemSignature[]);
    },
    [systemId, signaturesRef, outCommand, setSignatures],
  );

  return {
    handleGetSignatures,
    handleUpdateSignatures,
  };
}
