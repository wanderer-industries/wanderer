import { WindowStoreInfo } from '@/hooks/Mapper/mapRootProvider/hooks/useStoreWidgets.ts';
import { SignatureSettingsType } from '@/hooks/Mapper/constants/signatures.ts';

export enum AvailableThemes {
  default = 'default',
  pathfinder = 'pathfinder',
}

export enum MiniMapPlacement {
  rightTop = 'rightTop',
  rightBottom = 'rightBottom',
  leftTop = 'leftTop',
  leftBottom = 'leftBottom',
  hide = 'hide',
}

export enum PingsPlacement {
  rightTop = 'rightTop',
  rightBottom = 'rightBottom',
  leftTop = 'leftTop',
  leftBottom = 'leftBottom',
}

export type InterfaceStoredSettings = {
  isShowMenu: boolean;
  isShowKSpace: boolean;
  isThickConnections: boolean;
  isShowUnsplashedSignatures: boolean;
  isShowBackgroundPattern: boolean;
  isSoftBackground: boolean;
  theme: AvailableThemes;
  minimapPlacement: MiniMapPlacement;
  pingsPlacement: PingsPlacement;
};

export type RoutesType = {
  path_type: 'shortest' | 'secure' | 'insecure';
  include_mass_crit: boolean;
  include_eol: boolean;
  include_frig: boolean;
  include_cruise: boolean;
  include_thera: boolean;
  avoid_wormholes: boolean;
  avoid_pochven: boolean;
  avoid_edencom: boolean;
  avoid_triglavian: boolean;
  avoid: number[];
};

export type LocalWidgetSettings = {
  compact: boolean;
  showOffline: boolean;
  showShipName: boolean;
};

export type OnTheMapSettingsType = {
  hideOffline: boolean;
};

export type KillsWidgetSettings = {
  showAll: boolean;
  whOnly: boolean;
  excludedSystems: number[];
  timeRange: number;
};

export type MapViewPort = { zoom: number; x: number; y: number };

export type MapSettings = {
  viewport: MapViewPort;
};

export type SettingsWrapper<T> = T;

export type MapUserSettings = {
  migratedFromOld: boolean;
  version: number;
  widgets: SettingsWrapper<WindowStoreInfo>;
  interface: SettingsWrapper<InterfaceStoredSettings>;
  onTheMap: SettingsWrapper<OnTheMapSettingsType>;
  routes: SettingsWrapper<RoutesType>;
  localWidget: SettingsWrapper<LocalWidgetSettings>;
  signaturesWidget: SettingsWrapper<SignatureSettingsType>;
  killsWidget: SettingsWrapper<KillsWidgetSettings>;
  map: SettingsWrapper<MapSettings>;
};

export type MapUserSettingsStructure = {
  [mapId: string]: MapUserSettings;
};

export type WdResponse<T> = T;

export type RemoteAdminSettingsResponse = { default_settings?: string };

export enum SettingsTypes {
  killsWidget = 'killsWidget',
  localWidget = 'localWidget',
  widgets = 'widgets',
  routes = 'routes',
  onTheMap = 'onTheMap',
  signaturesWidget = 'signaturesWidget',
  interface = 'interface',
  map = 'map',
}

export type MigrationFunc = (prev: any) => any;
export type MigrationStructure = {
  to: number;
  up: MigrationFunc;
};
