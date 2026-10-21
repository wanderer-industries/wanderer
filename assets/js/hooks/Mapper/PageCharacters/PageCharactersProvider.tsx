import { createContext, useContext } from 'react';
import type { PageCharactersContextValue, PageCharactersProviderProps } from './types';
import { useCharacterAuthorization } from './hooks/useCharacterAuthorization';
import { useCharacterDeletion } from './hooks/useCharacterDeletion';
import { usePageCharactersData } from './hooks/usePageCharactersData';
import { usePageCharactersSettings } from './hooks/usePageCharactersSettings';

const PageCharactersContext = createContext<PageCharactersContextValue | null>(null);

export const PageCharactersProvider = ({ fwdRef, outCommand, children }: PageCharactersProviderProps) => {
  const data = usePageCharactersData(fwdRef, outCommand);
  const { settings, setViewMode, setShowBalances, setPromoHidden } = usePageCharactersSettings();
  const authorizeCharacter = useCharacterAuthorization(outCommand, data.setError);
  const deletion = useCharacterDeletion(data.characters, outCommand, data.setError);

  const value: PageCharactersContextValue = {
    status: data.status,
    error: data.error,
    characters: data.characters,
    filteredCharacters: data.filteredCharacters,
    walletTrackingEnabled: data.walletTrackingEnabled,
    query: data.query,
    viewMode: settings.viewMode,
    showBalances: settings.showBalances,
    promoHidden: settings.promoHidden,
    deletingCharacterId: deletion.deletingCharacterId,
    setQuery: data.setQuery,
    setViewMode,
    setShowBalances,
    setPromoHidden,
    authorizeCharacter,
    deleteCharacter: deletion.deleteCharacter,
    refresh: data.refresh,
  };

  return <PageCharactersContext.Provider value={value}>{children}</PageCharactersContext.Provider>;
};

export const usePageCharacters = (): PageCharactersContextValue => {
  const context = useContext(PageCharactersContext);
  if (!context) {
    throw new Error('usePageCharacters must be used within PageCharactersProvider');
  }

  return context;
};
