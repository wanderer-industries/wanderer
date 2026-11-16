import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useMemo } from 'react';

/**
 * Whether a system's intel is owned by this map's intel source, and so is
 * read-only here.
 *
 * Gates on the specific system rather than on "the map has a source": the sync
 * only copies systems the source map also has, so everything else on the
 * subscriber map stays editable.
 *
 * Advisory only — the server rejects these writes independently.
 */
export const useIsIntelInherited = (systemId?: string) => {
  const {
    data: { options },
  } = useMapRootState();

  const inheritedIds = options?.intel_inherited_system_ids;

  return useMemo(() => {
    if (!inheritedIds?.length || systemId == null) {
      return false;
    }

    return inheritedIds.includes(Number(systemId));
  }, [inheritedIds, systemId]);
};
