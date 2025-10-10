import { useMemo } from 'react';
import { CharacterTypeRaw } from '@/hooks/Mapper/types';

export type UseLocalCounterProps = {
  charactersInSystem: Array<CharacterTypeRaw>;
  userCharacters: string[];
};

export const getLocalCharacters = ({ charactersInSystem, userCharacters }: UseLocalCounterProps) => {
  return charactersInSystem
    .map(char => ({
      ...char,
      compact: true,
      isOwn: userCharacters.includes(char.eve_id),
    }))
    .sort((a, b) => a.name.localeCompare(b.name));
};

export const useLocalCounter = ({ charactersInSystem, userCharacters }: UseLocalCounterProps) => {
  const localCounterCharacters = useMemo(
    () => getLocalCharacters({ charactersInSystem, userCharacters }),
    [charactersInSystem, userCharacters],
  );

  return { localCounterCharacters };
};
