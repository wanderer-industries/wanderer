import { createDefaultPageCharactersSettings, normalizePageCharactersSettings } from '../defaults';
import { PAGE_CHARACTERS_SETTINGS_VERSION } from '../version';
import { PAGE_CHARACTERS_SETTINGS_MIGRATIONS } from './list';

const getStoredVersion = (value: unknown): number => {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    return 0;
  }

  const version = (value as Record<string, unknown>).version;
  if (typeof version !== 'number' || !Number.isInteger(version) || version < 0) {
    return 0;
  }

  return version;
};

export const applyPageCharactersSettingsMigrations = (value: unknown) => {
  const storedVersion = getStoredVersion(value);
  if (storedVersion > PAGE_CHARACTERS_SETTINGS_VERSION) {
    return createDefaultPageCharactersSettings();
  }

  let migratedValue = value;
  const pendingMigrations = PAGE_CHARACTERS_SETTINGS_MIGRATIONS.filter(migration => {
    return migration.to > storedVersion && migration.to <= PAGE_CHARACTERS_SETTINGS_VERSION;
  });

  for (const migration of pendingMigrations) {
    migratedValue = migration.up(migratedValue);
  }

  return normalizePageCharactersSettings(migratedValue);
};
