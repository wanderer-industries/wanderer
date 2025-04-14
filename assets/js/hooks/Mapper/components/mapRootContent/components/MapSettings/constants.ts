import { SettingsListItem, UserSettingsRemoteProps } from './types.ts';
import { AvailableThemes, InterfaceStoredSettingsProps } from '@/hooks/Mapper/mapRootProvider';

export const DEFAULT_REMOTE_SETTINGS = {
  [UserSettingsRemoteProps.link_signature_on_splash]: false,
  [UserSettingsRemoteProps.select_on_spash]: false,
  [UserSettingsRemoteProps.delete_connection_with_sigs]: false,
};

export const UserSettingsRemoteList = [
  UserSettingsRemoteProps.link_signature_on_splash,
  UserSettingsRemoteProps.select_on_spash,
  UserSettingsRemoteProps.delete_connection_with_sigs,
];

export const COMMON_CHECKBOXES_PROPS: SettingsListItem[] = [
  {
    prop: InterfaceStoredSettingsProps.isShowMinimap,
    label: 'Show Minimap',
    type: 'checkbox',
  },
];

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

export const CONNECTIONS_CHECKBOXES_PROPS: SettingsListItem[] = [
  {
    prop: UserSettingsRemoteProps.delete_connection_with_sigs,
    label: 'Delete connections to linked signatures',
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
