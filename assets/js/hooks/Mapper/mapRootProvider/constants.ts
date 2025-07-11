import {
  AvailableThemes,
  InterfaceStoredSettings,
  KillsWidgetSettings,
  LocalWidgetSettings,
  MiniMapPlacement,
  OnTheMapSettingsType,
  PingsPlacement,
  RoutesType,
} from '@/hooks/Mapper/mapRootProvider/types.ts';
import {
  CURRENT_WINDOWS_VERSION,
  DEFAULT_WIDGETS,
  STORED_VISIBLE_WIDGETS_DEFAULT,
} from '@/hooks/Mapper/components/mapInterface/constants.tsx';

export const STORED_INTERFACE_DEFAULT_VALUES: InterfaceStoredSettings = {
  isShowMenu: false,
  isShowKSpace: false,
  isThickConnections: false,
  isShowUnsplashedSignatures: false,
  isShowBackgroundPattern: true,
  isSoftBackground: false,
  theme: AvailableThemes.default,
  pingsPlacement: PingsPlacement.rightTop,
  minimapPlacement: MiniMapPlacement.rightBottom,
};

export const DEFAULT_ROUTES_SETTINGS: RoutesType = {
  path_type: 'shortest',
  include_mass_crit: true,
  include_eol: true,
  include_frig: true,
  include_cruise: true,
  include_thera: true,
  avoid_wormholes: false,
  avoid_pochven: false,
  avoid_edencom: false,
  avoid_triglavian: false,
  avoid: [],
};

export const DEFAULT_WIDGET_LOCAL_SETTINGS: LocalWidgetSettings = {
  compact: true,
  showOffline: false,
  version: 0,
  showShipName: false,
};

export const DEFAULT_ON_THE_MAP_SETTINGS: OnTheMapSettingsType = {
  hideOffline: false,
  version: 0,
};

export const DEFAULT_KILLS_WIDGET_SETTINGS: KillsWidgetSettings = {
  showAll: false,
  whOnly: true,
  excludedSystems: [],
  version: 2,
  timeRange: 4,
};

export const getDefaultWidgetProps = () => ({
  version: CURRENT_WINDOWS_VERSION,
  visible: STORED_VISIBLE_WIDGETS_DEFAULT,
  windows: DEFAULT_WIDGETS,
});
