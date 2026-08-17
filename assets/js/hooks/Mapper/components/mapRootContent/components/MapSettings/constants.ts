import { InterfaceStoredSettingsProps } from '@/hooks/Mapper/mapRootProvider';
import { AvailableThemes, MiniMapPlacement, PingsPlacement } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { SettingsListItem, UserSettingsRemoteProps } from './types.ts';
import {
  BUBBLE_BORDER_RANGE,
  BUBBLE_DEFAULT_COLOR,
  BUBBLE_OPACITY_RANGE,
  BUBBLE_SIZE_RANGE,
} from '@/hooks/Mapper/constants/connectionBubble.ts';

export { DEFAULT_REMOTE_SETTINGS, UserSettingsRemoteList } from '@/hooks/Mapper/constants/userSettings.ts';


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
    prop: UserSettingsRemoteProps.bookmark_return_hole_ignore,
    label: 'Ignore return hole when creating indexes',
    type: 'checkbox',
  },
  {
    prop: UserSettingsRemoteProps.bookmark_return_hole_symbol,
    label: 'Return hole symbol (use space for empty)',
    type: 'text',
    dependsOn: UserSettingsRemoteProps.bookmark_return_hole_ignore,
  },
  {
    prop: UserSettingsRemoteProps.bookmark_auto_temp_name,
    label: 'Auto-fill wormhole temporary name',
    type: 'template',
    placeholder: 'e.g. {chain_index}',
    helperText: 'Leave empty to disable.',
  },
];

export const SYSTEM_LABELS_SETTINGS_PROPS: SettingsListItem[] = [
  {
    prop: UserSettingsRemoteProps.system_custom_label_name,
    label: 'Auto-label jumped system',
    type: 'template',
    placeholder: 'e.g. WH-{chain_index}',
    helperText: 'Custom label written on the jumped system. Leave empty to disable.',
  },
  {
    prop: UserSettingsRemoteProps.system_auto_tag,
    label: 'Auto-tag jumped system',
    type: 'template',
    placeholder: 'e.g. {index}',
    helperText: 'Leave empty to disable.',
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

// The bubble drawn on a bubbled connection end. Leaving a setting empty keeps the theme's own
// value - see BUBBLE_CSS_VARS for the variables a theme can set.
export const CONNECTION_BUBBLE_SETTINGS_PROPS: SettingsListItem[] = [
  {
    prop: UserSettingsRemoteProps.connection_bubble_color,
    label: 'Bubble colour',
    type: 'color',
    fallback: BUBBLE_DEFAULT_COLOR,
  },
  {
    prop: UserSettingsRemoteProps.connection_bubble_size,
    label: 'Bubble size',
    type: 'number',
    min: BUBBLE_SIZE_RANGE.min,
    max: BUBBLE_SIZE_RANGE.max,
    suffix: ' px',
  },
  {
    prop: UserSettingsRemoteProps.connection_bubble_border,
    label: 'Bubble border',
    type: 'number',
    min: BUBBLE_BORDER_RANGE.min,
    max: BUBBLE_BORDER_RANGE.max,
    suffix: ' px',
  },
  {
    prop: UserSettingsRemoteProps.connection_bubble_opacity,
    label: 'Bubble fill',
    type: 'number',
    min: BUBBLE_OPACITY_RANGE.min,
    max: BUBBLE_OPACITY_RANGE.max,
    suffix: ' %',
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
  { label: 'Default Large', value: AvailableThemes.accessibleLarge },
  { label: 'Pathfinder', value: AvailableThemes.pathfinder },
  { label: 'High-contrast', value: AvailableThemes.accessibleDark },
  { label: 'High-contrast Large', value: AvailableThemes.accessibleLargeColorblind },
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
