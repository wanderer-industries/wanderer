import { InterfaceStoredSettingsProps } from '@/hooks/Mapper/mapRootProvider';
import { AvailableThemes, MiniMapPlacement, PingsPlacement } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { SettingsListItem, UserSettingsRemoteProps } from './types.ts';

export const DEFAULT_REMOTE_SETTINGS = {
  [UserSettingsRemoteProps.link_signature_on_splash]: false,
  [UserSettingsRemoteProps.select_on_spash]: false,
  [UserSettingsRemoteProps.delete_connection_with_sigs]: false,
  [UserSettingsRemoteProps.bookmark_name_format]: '',
  [UserSettingsRemoteProps.bookmark_custom_mapping]: {},
  [UserSettingsRemoteProps.bookmark_wormholes_start_at_zero]: false,
  [UserSettingsRemoteProps.bookmark_auto_copy]: true,
  [UserSettingsRemoteProps.bookmark_auto_temp_name]: '',
  [UserSettingsRemoteProps.system_auto_tag]: '',
  [UserSettingsRemoteProps.system_custom_label_name]: '',
};

export const AUTO_FORMAT_OPTIONS = [
  { label: 'Disabled', value: '' },
  { label: 'Numeric index (1, 2, 3)', value: 'index' },
  { label: 'Letter index (A, B, C)', value: 'index_letter' },
  { label: 'Numeric chain (11, 12, 121)', value: 'chain_index' },
  { label: 'Letter chain (A, A1, A21)', value: 'chain_index_letters' },
];

export const UserSettingsRemoteList = [
  UserSettingsRemoteProps.link_signature_on_splash,
  UserSettingsRemoteProps.select_on_spash,
  UserSettingsRemoteProps.delete_connection_with_sigs,
  UserSettingsRemoteProps.bookmark_name_format,
  UserSettingsRemoteProps.bookmark_custom_mapping,
  UserSettingsRemoteProps.bookmark_wormholes_start_at_zero,
  UserSettingsRemoteProps.bookmark_auto_copy,
  UserSettingsRemoteProps.bookmark_auto_temp_name,
  UserSettingsRemoteProps.system_auto_tag,
  UserSettingsRemoteProps.system_custom_label_name,
];

// export const COMMON_CHECKBOXES_PROPS: SettingsListItem[] = [
//   // {
//   //   prop: InterfaceStoredSettingsProps.isShowMinimap,
//   //   label: 'Show Minimap',
//   //   type: 'checkbox',
//   // },
// ];

export const SYSTEMS_CHECKBOXES_PROPS: SettingsListItem[] = [
  {
    prop: InterfaceStoredSettingsProps.isShowKSpace,
    label: 'Highlight Low/High-security systems',
    type: 'checkbox',
  },
  {
    prop: UserSettingsRemoteProps.select_on_spash,
    label: 'Auto-select splashed',
    type: 'checkbox',
  },
];

export const SIGNATURES_CHECKBOXES_PROPS: SettingsListItem[] = [
  {
    prop: UserSettingsRemoteProps.link_signature_on_splash,
    label: 'Link signature on splash',
    type: 'checkbox',
  },
  {
    prop: InterfaceStoredSettingsProps.isShowUnsplashedSignatures,
    label: 'Show unsplashed signatures',
    type: 'checkbox',
  },
];

export const BOOKMARKS_SETTINGS_PROPS: SettingsListItem[] = [
  {
    prop: UserSettingsRemoteProps.bookmark_auto_copy,
    label: 'Automatically copy bookmarks to clipboard',
    type: 'checkbox',
  },
  {
    prop: UserSettingsRemoteProps.bookmark_wormholes_start_at_zero,
    label: 'Start wormhole indices at 0',
    type: 'checkbox',
  },
  {
    prop: UserSettingsRemoteProps.bookmark_auto_temp_name,
    label: 'Auto-fill wormhole temporary name',
    type: 'dropdown',
    options: AUTO_FORMAT_OPTIONS,
  },
  {
    prop: UserSettingsRemoteProps.system_auto_tag,
    label: 'Auto-tag jumped system',
    type: 'dropdown',
    options: AUTO_FORMAT_OPTIONS,
  },
  {
    prop: UserSettingsRemoteProps.system_custom_label_name,
    label: 'Auto-label jumped system',
    type: 'dropdown',
    options: AUTO_FORMAT_OPTIONS,
  },
];

export const CONNECTIONS_CHECKBOXES_PROPS: SettingsListItem[] = [
  {
    prop: UserSettingsRemoteProps.delete_connection_with_sigs,
    label: 'Delete connections with linked signatures',
    type: 'checkbox',
  },
  {
    prop: InterfaceStoredSettingsProps.isThickConnections,
    label: 'Thicker connections',
    type: 'checkbox',
  },
];

export const UI_CHECKBOXES_PROPS: SettingsListItem[] = [
  {
    prop: InterfaceStoredSettingsProps.isShowMenu,
    label: 'Enable compact map menu bar',
    type: 'checkbox',
  },
  {
    prop: InterfaceStoredSettingsProps.isShowBackgroundPattern,
    label: 'Show background pattern',
    type: 'checkbox',
  },
  {
    prop: InterfaceStoredSettingsProps.isSoftBackground,
    label: 'Enable soft background',
    type: 'checkbox',
  },
];

export const THEME_OPTIONS = [
  { label: 'Default', value: AvailableThemes.default },
  { label: 'Pathfinder', value: AvailableThemes.pathfinder },
];

export const THEME_SETTING: SettingsListItem = {
  prop: 'theme',
  label: 'Theme',
  type: 'dropdown',
  options: THEME_OPTIONS,
};

export const MINI_MAP_PLACEMENT_OPTIONS = [
  { label: 'Right Bottom', value: MiniMapPlacement.rightBottom },
  { label: 'Right Top', value: MiniMapPlacement.rightTop },
  { label: 'Left Top', value: MiniMapPlacement.leftTop },
  { label: 'Left Bottom', value: MiniMapPlacement.leftBottom },
  { label: 'Hide', value: MiniMapPlacement.hide },
];

export const MINI_MAP_PLACEMENT: SettingsListItem = {
  prop: 'minimapPlacement',
  label: 'Minimap Placement',
  type: 'dropdown',
  options: MINI_MAP_PLACEMENT_OPTIONS,
};

export const PINGS_PLACEMENT_OPTIONS = [
  { label: 'Right Top', value: PingsPlacement.rightTop },
  { label: 'Left Top', value: PingsPlacement.leftTop },
  { label: 'Left Bottom', value: PingsPlacement.leftBottom },
  { label: 'Right Bottom', value: PingsPlacement.rightBottom },
];

export const PINGS_PLACEMENT: SettingsListItem = {
  prop: 'pingsPlacement',
  label: 'Pings Placement',
  type: 'dropdown',
  options: PINGS_PLACEMENT_OPTIONS,
};
