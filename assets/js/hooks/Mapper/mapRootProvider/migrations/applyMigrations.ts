import { MapUserSettingsStructure, MigrationStructure } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { getDefaultSettingsByType } from '@/hooks/Mapper/mapRootProvider/helpers/createDefaultWidgetSettings.ts';

const extractData = (localStoreKey = 'map-user-settings'): MapUserSettingsStructure | null => {
  const val = localStorage.getItem(localStoreKey);
  if (!val) {
    return null;
  }

  return JSON.parse(val);
};

export const applyMigrations = (
  mapId: string,
  migrations: MigrationStructure[],
  localStoreKey = 'map-user-settings',
) => {
  const currentLSData = extractData(localStoreKey);

  // INFO if we have NO any data in store expected that we will use default
  if (!currentLSData) {
    return;
  }

  const currentMapSettings = currentLSData[mapId];

  for (const migration of migrations) {
    const { to, run, type } = migration;
    const currentValue = currentMapSettings[type];

    if (!currentValue) {
      currentMapSettings[type] = getDefaultSettingsByType(type);
      continue;
    }

    // we skip if current version is older
    if (currentValue.version > to) {
      continue;
    }

    const next = run(currentValue.settings);
    currentMapSettings[type].version = to;
    currentMapSettings[type].settings = next;
  }

  return currentLSData;
};
