import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import {
  CommandCharacterAdded,
  CommandCharacterRemoved,
  CommandCharactersUpdated,
  CommandCharacterUpdated,
  CommandPresentCharacters,
} from '@/hooks/Mapper/types';
import { useCallback, useRef } from 'react';

export const useCommandsCharacters = () => {
  const { update } = useMapRootState();

  const ref = useRef({ update });
  ref.current = { update };

  const charactersUpdated = useCallback((updatedCharacters: CommandCharactersUpdated) => {
    ref.current.update(state => {
      const existing = state.characters ?? [];
      // Put updatedCharacters into a map keyed by ID
      const updatedMap = new Map(updatedCharacters.map(c => [c.eve_id, c]));

      // 1. Update existing characters when possible
      const merged = existing.map(character => {
        const updated = updatedMap.get(character.eve_id);
        if (updated) {
          updatedMap.delete(character.eve_id); // Mark as processed
          return { ...character, ...updated };
        }
        return character;
      });

      // 2. Any remaining items in updatedMap are NEW characters → add them
      const newCharacters = Array.from(updatedMap.values());

      return { characters: [...merged, ...newCharacters] };
    });
  }, []);

  const characterAdded = useCallback((value: CommandCharacterAdded) => {
    ref.current.update(state => {
      return { characters: [...state.characters.filter(x => x.eve_id !== value.eve_id), value] };
    });
  }, []);

  const characterRemoved = useCallback((value: CommandCharacterRemoved) => {
    ref.current.update(state => {
      return { characters: [...state.characters.filter(x => x.eve_id !== value.eve_id)] };
    });
  }, []);

  const characterUpdated = useCallback((value: CommandCharacterUpdated) => {
    ref.current.update(state => {
      return { characters: [...state.characters.filter(x => x.eve_id !== value.eve_id), value] };
    });
  }, []);

  const presentCharacters = useCallback((value: CommandPresentCharacters) => {
    ref.current.update(() => ({ presentCharacters: value }));
  }, []);

  return { charactersUpdated, characterAdded, characterRemoved, characterUpdated, presentCharacters };
};
