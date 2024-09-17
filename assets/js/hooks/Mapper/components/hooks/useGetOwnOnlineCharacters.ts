import { CharacterTypeRaw } from '@/hooks/Mapper/types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback, useRef } from 'react';

export const sortOnlineFunc = (a: CharacterTypeRaw, b: CharacterTypeRaw) =>
  a.online === b.online ? a.name.localeCompare(b.name) : a.online ? -1 : 1;

export const useGetOwnOnlineCharacters = () => {
  const {
    data: { characters, userCharacters },
  } = useMapRootState();

  const ref = useRef({ characters, userCharacters });
  ref.current = { characters, userCharacters };

  return useCallback(() => {
    const { characters, userCharacters } = ref.current;
    return characters.filter(x => userCharacters.includes(x.eve_id)).sort(sortOnlineFunc);
  }, []);
};
