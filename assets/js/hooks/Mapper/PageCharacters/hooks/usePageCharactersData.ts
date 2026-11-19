import { useCallback, useMemo, useState } from 'react';
import type { ForwardedRef } from 'react';
import type {
  PageCharacter,
  PageCharactersHandlers,
  PageCharactersOutCommandHandler,
  PageCharactersSnapshot,
} from '../types';
import { PageCharactersOutCommand, PageCharactersStatus } from '../types';
import { filterCharacters } from '../utils';
import { usePageCharactersEventHandlers } from './usePageCharactersEventHandlers';

const EMPTY_SNAPSHOT: PageCharactersSnapshot = {
  characters: [],
  wallet_tracking_enabled: false,
};

export const usePageCharactersData = (
  fwdRef: ForwardedRef<PageCharactersHandlers>,
  outCommand: PageCharactersOutCommandHandler,
) => {
  const [status, setStatus] = useState<PageCharactersStatus>(PageCharactersStatus.loading);
  const [error, setError] = useState<string | null>(null);
  const [snapshot, setSnapshot] = useState<PageCharactersSnapshot>(EMPTY_SNAPSHOT);
  const [query, setQuery] = useState('');

  const applySnapshot = useCallback((nextSnapshot: PageCharactersSnapshot) => {
    setSnapshot(nextSnapshot);
    setStatus(PageCharactersStatus.ready);
    setError(null);
  }, []);

  const applyCharacterUpdate = useCallback((updatedCharacter: PageCharacter) => {
    setSnapshot(currentSnapshot => ({
      ...currentSnapshot,
      characters: currentSnapshot.characters.map(character => {
        if (character.id === updatedCharacter.id) return updatedCharacter;
        return character;
      }),
    }));
  }, []);

  usePageCharactersEventHandlers(fwdRef, applySnapshot, applyCharacterUpdate);

  const refresh = useCallback(() => {
    setStatus(currentStatus => {
      if (currentStatus === PageCharactersStatus.ready) return currentStatus;
      return PageCharactersStatus.loading;
    });
    void outCommand({ type: PageCharactersOutCommand.init, data: {} });
  }, [outCommand]);

  const filteredCharacters = useMemo(() => filterCharacters(snapshot.characters, query), [query, snapshot.characters]);

  return {
    status,
    error,
    setError,
    characters: snapshot.characters,
    filteredCharacters,
    walletTrackingEnabled: snapshot.wallet_tracking_enabled,
    query,
    setQuery,
    refresh,
  };
};
