import type { PageCharacter } from './types';
import {
  filterCharacters,
  formatWalletBalance,
  getCharacterPortraitUrl,
  getDockedAt,
  getShipRenderUrl,
  isUnknownStructure,
} from './utils';

const CHARACTER: PageCharacter = {
  id: 'character-id',
  eve_id: '2112345678',
  name: 'Explorer One',
  corporation_id: 1000169,
  corporation_name: 'Signal Cartel',
  corporation_ticker: 'SC',
  alliance_id: 99009260,
  alliance_name: 'EvE-Scout Enclave',
  alliance_ticker: 'EVE-SCOUT',
  location_name: 'Thera',
  station_id: null,
  station_name: null,
  structure_id: null,
  system_info: {
    solar_system_id: 31000005,
    solar_system_name: 'Thera',
    region_name: 'Anoikis',
    system_class: 12,
    security: '-0.99',
    class_title: 'C12',
  },
  ship_name: 'Buzzard',
  ship_type_id: 11192,
  wallet_balance: 1_250_000,
  show_wallet_balance: true,
  online: true,
  invalid_token: false,
};

describe('PageCharacters utilities', () => {
  it('searches all visible character fields case-insensitively', () => {
    expect(filterCharacters([CHARACTER], 'thera')).toEqual([CHARACTER]);
    expect(filterCharacters([CHARACTER], 'signal')).toEqual([CHARACTER]);
    expect(filterCharacters([CHARACTER], 'missing')).toEqual([]);
  });

  it('formats wallet balances and portrait URLs', () => {
    expect(formatWalletBalance(1_250_000)).toBe('ISK 1.25M');
    expect(getCharacterPortraitUrl(CHARACTER.eve_id)).toContain(`/characters/${CHARACTER.eve_id}/portrait`);
    expect(getShipRenderUrl(45647)).toBe(
      'https://wanderer-industries.github.io/wanderer-assets/images/phantom-ship-renders/1024x512/45647.png',
    );
  });

  it('describes the current docking location', () => {
    expect(getDockedAt(CHARACTER)).toBe('In Space');
    expect(getDockedAt({ ...CHARACTER, station_id: 60003760, station_name: 'Jita IV - Moon 4' })).toBe(
      'Jita IV - Moon 4',
    );
    expect(getDockedAt({ ...CHARACTER, structure_id: 1_000_000_000_001 })).toBe('Unknown structure');
    expect(getDockedAt({ ...CHARACTER, station_id: 60003760 })).toBe('Unknown station');
    expect(isUnknownStructure({ ...CHARACTER, structure_id: 1_000_000_000_001 })).toBe(true);
  });
});
