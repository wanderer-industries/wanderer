import { useMapState } from '@/hooks/Mapper/components/map/MapProvider.tsx';
import {
  CommandCharacterAdded,
  CommandCharacterRemoved,
  CommandCharactersUpdated,
  CommandCharacterUpdated,
  CommandPresentCharacters,
} from '@/hooks/Mapper/types';
import { useCallback, useRef } from 'react';

export const useCommandsCharacters = () => {
  const { update } = useMapState();

  const ref = useRef({ update });
  ref.current = { update };

  const charactersUpdated = useCallback((characters: CommandCharactersUpdated) => {
    ref.current.update(() => ({ characters: characters.slice() }));
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

  return { charactersUpdated, presentCharacters, characterAdded, characterRemoved, characterUpdated };
};
