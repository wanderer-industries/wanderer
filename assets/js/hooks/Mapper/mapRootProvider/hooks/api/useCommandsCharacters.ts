import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback, useRef } from 'react';
import {
  CommandCharacterAdded,
  CommandCharacterRemoved,
  CommandCharactersUpdated,
  CommandCharacterUpdated,
  CommandPresentCharacters,
  CommandReadyCharactersUpdated,
  CommandAllReadyCharactersCleared,
} from '@/hooks/Mapper/types';

export const useCommandsCharacters = () => {
  const { update } = useMapRootState();

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

  const readyCharactersUpdated = useCallback((value: CommandReadyCharactersUpdated) => {
    const { ready_character_eve_ids } = value;
    ref.current.update(state => ({
      characters: state.characters.map(char => ({
        ...char,
        ready: ready_character_eve_ids.includes(char.eve_id),
      })),
    }));
  }, []);

  const allReadyCharactersCleared = useCallback(
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    (_value: CommandAllReadyCharactersCleared) => {
      // Clear all ready status for all characters
      // Note: _value contains cleared_by_user_id but we don't need it for this operation
      ref.current.update(state => ({
        characters: state.characters.map(char => ({
          ...char,
          ready: false,
        })),
      }));
    },
    [],
  );

  return {
    charactersUpdated,
    characterAdded,
    characterRemoved,
    characterUpdated,
    presentCharacters,
    readyCharactersUpdated,
    allReadyCharactersCleared,
  };
};
