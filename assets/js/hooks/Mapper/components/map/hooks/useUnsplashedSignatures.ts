import { useMemo } from 'react';
import { SystemSignature } from '@/hooks/Mapper/types';
import { prepareUnsplashedChunks } from '@/hooks/Mapper/components/map/helpers';

export type UnsplashedSignatureType = SystemSignature & { sig_id: string };

export function useUnsplashedSignatures(systemSigs: SystemSignature[], isShowUnsplashedSignatures: boolean) {
  return useMemo(() => {
    if (!isShowUnsplashedSignatures) {
      return {
        unsplashedLeft: [] as SystemSignature[],
        unsplashedRight: [] as SystemSignature[],
      };
    }
    const chunks = prepareUnsplashedChunks(
      systemSigs
        .filter(s => s.group === 'Wormhole' && !s.linked_system)
        .map(s => ({
          eve_id: s.eve_id,
          type: s.type,
          custom_info: s.custom_info,
          kind: s.kind,
          name: s.name,
          group: s.group,
        })) as UnsplashedSignatureType[],
    );
    const [unsplashedLeft, unsplashedRight] = chunks;
    return { unsplashedLeft, unsplashedRight };
  }, [isShowUnsplashedSignatures, systemSigs]);
}
