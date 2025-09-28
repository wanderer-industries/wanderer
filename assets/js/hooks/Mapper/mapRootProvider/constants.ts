import {
  AvailableThemes,
  InterfaceStoredSettings,
  KillsWidgetSettings,
  LocalWidgetSettings,
  MapSettings,
  MiniMapPlacement,
  OnTheMapSettingsType,
  PingsPlacement,
  RoutesType,
} from '@/hooks/Mapper/mapRootProvider/types.ts';
import { DEFAULT_WIDGETS, STORED_VISIBLE_WIDGETS_DEFAULT } from '@/hooks/Mapper/components/mapInterface/constants.tsx';

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
  showShipName: false,
};

export const DEFAULT_ON_THE_MAP_SETTINGS: OnTheMapSettingsType = {
  hideOffline: false,
};

export const DEFAULT_KILLS_WIDGET_SETTINGS: KillsWidgetSettings = {
  showAll: false,
  whOnly: true,
  excludedSystems: [],
  timeRange: 4,
};

export const DEFAULT_MAP_SETTINGS: MapSettings = {
  viewport: { zoom: 1, x: 0, y: 0 },
};

export const getDefaultWidgetProps = () => ({
  visible: STORED_VISIBLE_WIDGETS_DEFAULT,
  windows: DEFAULT_WIDGETS,
});
