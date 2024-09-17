import { useCallback, useRef } from 'react';
import { CommandMapUpdated } from '@/hooks/Mapper/types/mapHandlers.ts';
import { MapRootData, useMapRootState } from '@/hooks/Mapper/mapRootProvider';

export const useMapUpdated = () => {
  const { update } = useMapRootState();

  const ref = useRef({ update });
  ref.current = { update };

  return useCallback(({ hubs }: CommandMapUpdated) => {
    const { update } = ref.current;

    const out: Partial<MapRootData> = {};

    if (hubs) {
      out.hubs = hubs;
    }

    update(out);
  }, []);
};
