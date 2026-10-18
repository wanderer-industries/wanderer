import type { PageCharacter } from './types';

const WALLET_FORMATTER = new Intl.NumberFormat('en', {
  notation: 'compact',
  maximumFractionDigits: 2,
});

const PHANTOM_SHIP_RENDERS_BASE_URL =
  'https://wanderer-industries.github.io/wanderer-assets/images/phantom-ship-renders/1024x512';

export const filterCharacters = (characters: PageCharacter[], query: string): PageCharacter[] => {
  const normalizedQuery = query.trim().toLocaleLowerCase();
  if (!normalizedQuery) {
    return characters;
  }

  return characters.filter(character => {
    const searchableValues = [
      character.name,
      character.corporation_name,
      character.corporation_ticker,
      character.alliance_name,
      character.alliance_ticker,
      character.location_name,
      character.ship_name,
    ];

    return searchableValues.some(value => value?.toLocaleLowerCase().includes(normalizedQuery));
  });
};

export const formatWalletBalance = (balance: number): string => {
  return `ISK ${WALLET_FORMATTER.format(balance)}`;
};

export const getCharacterPortraitUrl = (eveId: string): string => {
  return `https://images.evetech.net/characters/${eveId}/portrait?size=256`;
};

export const getShipRenderUrl = (shipTypeId: number): string => {
  return `${PHANTOM_SHIP_RENDERS_BASE_URL}/${shipTypeId}.png`;
};
