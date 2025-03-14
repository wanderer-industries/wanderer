import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useEffect, useMemo, useRef } from 'react';

export const useGetCacheCharacter = (characterEveId: string | undefined) => {
  const {
    charactersCache: { characters, loadCharacter, lastUpdateKey },
  } = useMapRootState();

  const ref = useRef({ loadCharacter });
  ref.current = { loadCharacter };

  useEffect(() => {
    if (!characterEveId) {
      return;
    }

    ref.current.loadCharacter(characterEveId);
  }, [characterEveId]);

  return useMemo(() => {
    if (!characterEveId) {
      return;
    }

    return characters.get(characterEveId);
  }, [characters, lastUpdateKey]);
};
