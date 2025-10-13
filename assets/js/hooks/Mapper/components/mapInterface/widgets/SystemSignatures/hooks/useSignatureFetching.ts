import { SETTINGS_KEYS } from '@/hooks/Mapper/constants/signatures';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { ExtendedSystemSignature, SystemSignature } from '@/hooks/Mapper/types';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { useCallback, useMemo } from 'react';
import { getDeletionTimeoutMs } from '../constants';
import { getActualSigs, prepareUpdatePayload } from '../helpers';
import { UseFetchingParams } from './types';

export const useSignatureFetching = ({ systemId, settings, signaturesRef, setSignatures }: UseFetchingParams) => {
  const {
    data: { characters },
    outCommand,
  } = useMapRootState();

  const deleteTimeout = useMemo(() => {
    const lazyDelete = settings[SETTINGS_KEYS.LAZY_DELETE_SIGNATURES] as boolean;
    if (!lazyDelete) {
      return 0;
    }

    return getDeletionTimeoutMs(settings);
  }, [settings]);

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

    setSignatures(() => extended);
  }, [characters, systemId, outCommand]);

  const handleUpdateSignatures = useCallback(
    async (newList: ExtendedSystemSignature[], updateOnly: boolean, skipUpdateUntouched?: boolean) => {
      const actualSigs = getActualSigs(signaturesRef.current, newList, updateOnly, skipUpdateUntouched);

      const { added, updated, removed } = actualSigs;

      if (updated.length !== 0 || added.length !== 0 || removed.length !== 0) {
        await outCommand({
          type: OutCommand.updateSignatures,
          data: { ...prepareUpdatePayload(systemId, added, updated, removed), deleteTimeout },
        });
      }
    },
    [systemId, deleteTimeout, outCommand, signaturesRef],
  );

  return {
    handleGetSignatures,
    handleUpdateSignatures,
  };
};
