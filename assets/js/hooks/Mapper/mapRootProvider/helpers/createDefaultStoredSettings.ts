import { MapUserSettings, SettingsTypes, SettingsWrapper } from '@/hooks/Mapper/mapRootProvider/types.ts';
import {
  DEFAULT_KILLS_WIDGET_SETTINGS,
  DEFAULT_MAP_SETTINGS,
  DEFAULT_ON_THE_MAP_SETTINGS,
  DEFAULT_ROUTES_SETTINGS,
  DEFAULT_WIDGET_LOCAL_SETTINGS,
  getDefaultWidgetProps,
  STORED_INTERFACE_DEFAULT_VALUES,
} from '@/hooks/Mapper/mapRootProvider/constants.ts';
import { DEFAULT_SIGNATURE_SETTINGS } from '@/hooks/Mapper/constants/signatures.ts';
import { STORED_SETTINGS_VERSION } from '@/hooks/Mapper/mapRootProvider/version.ts';

// TODO - we need provide and compare version
export const createWidgetSettings = <T>(settings: T) => {
  return settings;
};

export const createDefaultStoredSettings = (): MapUserSettings => {
  return {
    version: STORED_SETTINGS_VERSION,
    migratedFromOld: false,
    killsWidget: createWidgetSettings(DEFAULT_KILLS_WIDGET_SETTINGS),
    localWidget: createWidgetSettings(DEFAULT_WIDGET_LOCAL_SETTINGS),
    widgets: createWidgetSettings(getDefaultWidgetProps()),
    routes: createWidgetSettings(DEFAULT_ROUTES_SETTINGS),
    onTheMap: createWidgetSettings(DEFAULT_ON_THE_MAP_SETTINGS),
    signaturesWidget: createWidgetSettings(DEFAULT_SIGNATURE_SETTINGS),
    interface: createWidgetSettings(STORED_INTERFACE_DEFAULT_VALUES),
    map: createWidgetSettings(DEFAULT_MAP_SETTINGS),
  };
};

// INFO - in another case need to generate complex type - but looks like it unnecessary
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const getDefaultSettingsByType = (type: SettingsTypes): SettingsWrapper<any> => {
  switch (type) {
    case SettingsTypes.killsWidget:
      return createWidgetSettings(DEFAULT_KILLS_WIDGET_SETTINGS);
    case SettingsTypes.localWidget:
      return createWidgetSettings(DEFAULT_WIDGET_LOCAL_SETTINGS);
    case SettingsTypes.widgets:
      return createWidgetSettings(getDefaultWidgetProps());
    case SettingsTypes.routes:
      return createWidgetSettings(DEFAULT_ROUTES_SETTINGS);
    case SettingsTypes.onTheMap:
      return createWidgetSettings(DEFAULT_ON_THE_MAP_SETTINGS);
    case SettingsTypes.signaturesWidget:
      return createWidgetSettings(DEFAULT_SIGNATURE_SETTINGS);
    case SettingsTypes.interface:
      return createWidgetSettings(STORED_INTERFACE_DEFAULT_VALUES);
    case SettingsTypes.map:
      return createWidgetSettings(DEFAULT_MAP_SETTINGS);
  }
};
