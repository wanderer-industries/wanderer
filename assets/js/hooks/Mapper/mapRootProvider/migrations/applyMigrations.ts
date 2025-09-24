import { MapUserSettingsStructure } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { STORED_SETTINGS_VERSION } from '@/hooks/Mapper/mapRootProvider/version.ts';
import { migrations } from '@/hooks/Mapper/mapRootProvider/migrations/index.ts';

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

    return;
  }

  // Upgrade
  if (direction > 0) {
    const preparedMigrations = migrations.sort((a, b) => a.to - b.to).filter(x => x.to <= STORED_SETTINGS_VERSION);

    for (const migration of preparedMigrations) {
      const { to, up } = migration;

      const next = up(currentMapSettings);
      currentMapSettings = { ...next, version: to, migratedFromOld: true };
    }

    return currentMapSettings;
  }

  // DOWNGRADE
  const preparedMigrations = migrations.sort((a, b) => b.to - a.to).filter(x => x.to - 1 >= STORED_SETTINGS_VERSION);

  for (const migration of preparedMigrations) {
    const { to, down } = migration;

    const next = down(currentMapSettings);
    currentMapSettings = { ...next, version: to - 1, migratedFromOld: true };
  }

  return currentMapSettings;
};
