import { MapUserSettingsStructure } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { STORED_SETTINGS_VERSION } from '@/hooks/Mapper/mapRootProvider/version.ts';
import { migrations } from '@/hooks/Mapper/mapRootProvider/migrations/index.ts';
import { createDefaultStoredSettings } from '@/hooks/Mapper/mapRootProvider/helpers/createDefaultStoredSettings.ts';

export const extractData = (localStoreKey = 'map-user-settings'): MapUserSettingsStructure | null => {
  const val = localStorage.getItem(localStoreKey);
  if (!val) {
    return null;
  }

  return JSON.parse(val);
};

export const applyMigrations = (mapSettings: any) => {
  let currentMapSettings = { ...mapSettings };

  // INFO if we have NO any data in store expected that we will use default
  if (!currentMapSettings) {
    return;
  }

  const direction = STORED_SETTINGS_VERSION - (currentMapSettings.version || 0);
  if (direction === 0) {
    if (currentMapSettings.version == null) {
      return { ...currentMapSettings, version: STORED_SETTINGS_VERSION, migratedFromOld: true };
    }

    return currentMapSettings;
  }

  const cmVersion = currentMapSettings.version || 0;

  // downgrade
  // INFO: when we downgrading - if diff between >= 1 it means was major version
  if (direction < 0) {
    // If was minor version - we do nothing
    if (Math.abs(direction) < 1) {
      return currentMapSettings;
    }

    // if was major version - we set default settings
    return createDefaultStoredSettings();
  }

  const preparedMigrations = migrations
    .sort((a, b) => a.to - b.to)
    .filter(x => x.to > cmVersion && x.to <= STORED_SETTINGS_VERSION);

  for (const migration of preparedMigrations) {
    const { to, up } = migration;

    const next = up(currentMapSettings);
    currentMapSettings = { ...next, version: to, migratedFromOld: true };
  }

  return currentMapSettings;
};
