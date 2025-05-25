import {
  AvailableThemes,
  InterfaceStoredSettings,
  MiniMapPlacement,
  PingsPlacement,
  RoutesType,
} from '@/hooks/Mapper/mapRootProvider/types.ts';

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
