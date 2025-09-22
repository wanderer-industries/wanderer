import { MapUserSettings, MigrationTypes, SettingsWithVersion } from '@/hooks/Mapper/mapRootProvider/types.ts';
import {
  DEFAULT_KILLS_WIDGET_SETTINGS,
  DEFAULT_ON_THE_MAP_SETTINGS,
  DEFAULT_ROUTES_SETTINGS,
  DEFAULT_WIDGET_LOCAL_SETTINGS,
  getDefaultWidgetProps,
  STORED_INTERFACE_DEFAULT_VALUES,
} from '@/hooks/Mapper/mapRootProvider/constants.ts';
import { DEFAULT_SIGNATURE_SETTINGS } from '@/hooks/Mapper/constants/signatures.ts';
import { SETTING_VERSIONS } from '@/hooks/Mapper/mapRootProvider/versions.ts';

// TODO - we need provide and compare version
export const createWidgetSettingsWithVersion = <T>(version: number, settings: T) => {
  return {
    version,
    settings,
  };
};

export const createDefaultWidgetSettings = (): MapUserSettings => {
  return {
    killsWidget: createWidgetSettingsWithVersion(SETTING_VERSIONS.kills, DEFAULT_KILLS_WIDGET_SETTINGS),
    localWidget: createWidgetSettingsWithVersion(SETTING_VERSIONS.localWidget, DEFAULT_WIDGET_LOCAL_SETTINGS),
    widgets: createWidgetSettingsWithVersion(SETTING_VERSIONS.widgets, getDefaultWidgetProps()),
    routes: createWidgetSettingsWithVersion(SETTING_VERSIONS.routes, DEFAULT_ROUTES_SETTINGS),
    onTheMap: createWidgetSettingsWithVersion(SETTING_VERSIONS.onTheMap, DEFAULT_ON_THE_MAP_SETTINGS),
    signaturesWidget: createWidgetSettingsWithVersion(SETTING_VERSIONS.signatures, DEFAULT_SIGNATURE_SETTINGS),
    interface: createWidgetSettingsWithVersion(SETTING_VERSIONS.interface, STORED_INTERFACE_DEFAULT_VALUES),
  };
};

// INFO - in another case need to generate complex type - but looks like it unnecessary
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const getDefaultSettingsByType = (type: MigrationTypes): SettingsWithVersion<any> => {
  switch (type) {
    case MigrationTypes.killsWidget:
      return createWidgetSettingsWithVersion(SETTING_VERSIONS.kills, DEFAULT_KILLS_WIDGET_SETTINGS);
    case MigrationTypes.localWidget:
      return createWidgetSettingsWithVersion(SETTING_VERSIONS.localWidget, DEFAULT_WIDGET_LOCAL_SETTINGS);
    case MigrationTypes.widgets:
      return createWidgetSettingsWithVersion(SETTING_VERSIONS.widgets, getDefaultWidgetProps());
    case MigrationTypes.routes:
      return createWidgetSettingsWithVersion(SETTING_VERSIONS.routes, DEFAULT_ROUTES_SETTINGS);
    case MigrationTypes.onTheMap:
      return createWidgetSettingsWithVersion(SETTING_VERSIONS.onTheMap, DEFAULT_ON_THE_MAP_SETTINGS);
    case MigrationTypes.signaturesWidget:
      return createWidgetSettingsWithVersion(SETTING_VERSIONS.signatures, DEFAULT_SIGNATURE_SETTINGS);
    case MigrationTypes.interface:
      return createWidgetSettingsWithVersion(SETTING_VERSIONS.interface, STORED_INTERFACE_DEFAULT_VALUES);
  }
};
