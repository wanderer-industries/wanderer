import { useCallback, useRef, useState } from 'react';
import { CharacterCache, OutCommand, OutCommandHandler, UseCharactersCacheData } from '@/hooks/Mapper/types';

interface UseCharactersCacheProps {
  outCommand: OutCommandHandler;
}
export const useCharactersCache = ({ outCommand }: UseCharactersCacheProps): UseCharactersCacheData => {
  const charactersRef = useRef<Map<string, CharacterCache>>(new Map());
  const [lastUpdateKey, setLastUpdateKey] = useState(0);

  const loadCharacter = useCallback(async (characterId: string) => {
    let character = charactersRef.current.get(characterId);

    if (character?.loading || character?.loaded) {
      return;
    }

    if (!character) {
      character = {
        loading: false,
        loaded: false,
        data: null,
      };
    }

    character.loading = true;
    charactersRef.current.set(characterId, character);

    try {
      const res = await outCommand({
        type: OutCommand.getCharacterInfo,
        data: { characterEveId: characterId },
      });
      character.data = res;
      character.loaded = true;
    } catch (error) {
      console.error(error);
    }

    charactersRef.current.set(characterId, character);
    character.loading = false;
    setLastUpdateKey(x => x + 1);
  }, []);

  return { loadCharacter, characters: charactersRef.current, lastUpdateKey };
};
