import { createContext, useCallback, useContext, useMemo, useState } from 'react';
import { useToast } from '@/hooks/Mapper/ToastProvider';
import type {
  PageCharactersCommandReply,
  PageCharactersContextValue,
  PageCharacter,
  PageCharactersProviderProps,
  PageCharactersSnapshot,
  PageCharactersStatus,
  PageCharactersViewMode,
} from './types';
import { PageCharactersOutCommand } from './types';
import { filterCharacters } from './utils';
import { usePageCharactersEventHandlers } from './hooks/usePageCharactersEventHandlers';
import { usePageCharactersSettings } from './hooks/usePageCharactersSettings';

const PageCharactersContext = createContext<PageCharactersContextValue | null>(null);

export const PageCharactersProvider = ({ fwdRef, outCommand, children }: PageCharactersProviderProps) => {
  const { show: showToast } = useToast();
  const { settings, updateSettings } = usePageCharactersSettings();
  const [status, setStatus] = useState<PageCharactersStatus>('loading');
  const [error, setError] = useState<string | null>(null);
  const [snapshot, setSnapshot] = useState<PageCharactersSnapshot>({
    characters: [],
    wallet_tracking_enabled: false,
  });
  const [query, setQuery] = useState('');
  const [deletingCharacterId, setDeletingCharacterId] = useState<string | null>(null);

  const applySnapshot = useCallback((nextSnapshot: PageCharactersSnapshot) => {
    setSnapshot(nextSnapshot);
    setStatus('ready');
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
    setStatus(currentStatus => (currentStatus === 'ready' ? currentStatus : 'loading'));
    void outCommand({ type: PageCharactersOutCommand.init, data: {} });
  }, [outCommand]);

  const setViewMode = useCallback(
    (mode: PageCharactersViewMode) => {
      updateSettings({ viewMode: mode });
    },
    [updateSettings],
  );

  const setShowBalances = useCallback(
    (show: boolean) => {
      updateSettings({ showBalances: show });
    },
    [updateSettings],
  );

  const setPromoHidden = useCallback(
    (hidden: boolean) => {
      updateSettings({ promoHidden: hidden });
    },
    [updateSettings],
  );

  const authorizeCharacter = useCallback(
    async (trackWallet: boolean) => {
      const reply = await outCommand<PageCharactersCommandReply>({
        type: PageCharactersOutCommand.authorize,
        data: { track_wallet: trackWallet },
      });

      if (!reply.ok) {
        const message = reply.error ?? 'Unable to start EVE authorization.';
        setError(message);
        showToast({ severity: 'error', summary: 'Authorization failed', detail: message });
      }
    },
    [outCommand, showToast],
  );

  const deleteCharacter = useCallback(
    async (characterId: string) => {
      setDeletingCharacterId(characterId);

      try {
        const reply = await outCommand<PageCharactersCommandReply>({
          type: PageCharactersOutCommand.delete,
          data: { character_id: characterId },
        });

        if (!reply.ok) {
          const message = reply.error ?? 'Unable to delete character.';
          setError(message);
          showToast({ severity: 'error', summary: 'Delete failed', detail: message });
          return false;
        }

        if (reply.snapshot) {
          applySnapshot(reply.snapshot);
        }

        showToast({ severity: 'success', summary: 'Character removed' });
        return true;
      } finally {
        setDeletingCharacterId(null);
      }
    },
    [applySnapshot, outCommand, showToast],
  );

  const filteredCharacters = useMemo(() => filterCharacters(snapshot.characters, query), [query, snapshot.characters]);

  const value = useMemo<PageCharactersContextValue>(
    () => ({
      status,
      error,
      characters: snapshot.characters,
      filteredCharacters,
      walletTrackingEnabled: snapshot.wallet_tracking_enabled,
      query,
      viewMode: settings.viewMode,
      showBalances: settings.showBalances,
      promoHidden: settings.promoHidden,
      deletingCharacterId,
      setQuery,
      setViewMode,
      setShowBalances,
      setPromoHidden,
      authorizeCharacter,
      deleteCharacter,
      refresh,
    }),
    [
      authorizeCharacter,
      deleteCharacter,
      deletingCharacterId,
      error,
      filteredCharacters,
      query,
      refresh,
      setPromoHidden,
      settings.promoHidden,
      settings.showBalances,
      settings.viewMode,
      snapshot.characters,
      snapshot.wallet_tracking_enabled,
      status,
      setViewMode,
    ],
  );

  return <PageCharactersContext.Provider value={value}>{children}</PageCharactersContext.Provider>;
};

export const usePageCharacters = (): PageCharactersContextValue => {
  const context = useContext(PageCharactersContext);
  if (!context) {
    throw new Error('usePageCharacters must be used within PageCharactersProvider');
  }

  return context;
};
