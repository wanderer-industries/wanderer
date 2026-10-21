import { createDefaultPageCharactersSettings } from '../defaults';
import { applyPageCharactersSettingsMigrations } from './applyMigrations';

describe('PageCharacters settings migrations', () => {
  it('creates versioned defaults for an empty value', () => {
    expect(applyPageCharactersSettingsMigrations(undefined)).toEqual(createDefaultPageCharactersSettings());
  });

  it('migrates an unversioned PageCharacters settings object', () => {
    expect(
      applyPageCharactersSettingsMigrations({
        viewMode: 'eve',
        showBalances: true,
        promoHidden: true,
      }),
    ).toEqual({
      version: 1,
      viewMode: 'eve',
      showBalances: true,
      promoHidden: true,
    });
  });

  it('normalizes corrupted fields without discarding valid settings', () => {
    expect(
      applyPageCharactersSettingsMigrations({
        version: 1,
        viewMode: 'broken',
        showBalances: true,
        promoHidden: 'yes',
      }),
    ).toEqual({
      version: 1,
      viewMode: 'cards',
      showBalances: true,
      promoHidden: false,
    });
  });

  it('resets settings written by a newer incompatible schema', () => {
    expect(applyPageCharactersSettingsMigrations({ version: 2, viewMode: 'eve' })).toEqual(
      createDefaultPageCharactersSettings(),
    );
  });
});
