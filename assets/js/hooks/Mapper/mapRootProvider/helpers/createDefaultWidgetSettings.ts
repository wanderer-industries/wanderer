import { MapUserSettings } from '@/hooks/Mapper/mapRootProvider/types.ts';
import {
  DEFAULT_KILLS_WIDGET_SETTINGS,
  DEFAULT_ON_THE_MAP_SETTINGS,
  DEFAULT_ROUTES_SETTINGS,
  DEFAULT_WIDGET_LOCAL_SETTINGS,
  getDefaultWidgetProps,
  STORED_INTERFACE_DEFAULT_VALUES,
} from '@/hooks/Mapper/mapRootProvider/constants.ts';
import { DEFAULT_SIGNATURE_SETTINGS } from '@/hooks/Mapper/constants/signatures.ts';

// TODO - we need provide and compare version
const createWidgetSettingsWithVersion = <T>(settings: T) => {
  return {
    version: 0,
    settings,
  };
};

export const createDefaultWidgetSettings = (): MapUserSettings => {
  return {
    killsWidget: createWidgetSettingsWithVersion(DEFAULT_KILLS_WIDGET_SETTINGS),
    localWidget: createWidgetSettingsWithVersion(DEFAULT_WIDGET_LOCAL_SETTINGS),
    widgets: createWidgetSettingsWithVersion(getDefaultWidgetProps()),
    routes: createWidgetSettingsWithVersion(DEFAULT_ROUTES_SETTINGS),
    onTheMap: createWidgetSettingsWithVersion(DEFAULT_ON_THE_MAP_SETTINGS),
    signaturesWidget: createWidgetSettingsWithVersion(DEFAULT_SIGNATURE_SETTINGS),
    interface: createWidgetSettingsWithVersion(STORED_INTERFACE_DEFAULT_VALUES),
  };
};
