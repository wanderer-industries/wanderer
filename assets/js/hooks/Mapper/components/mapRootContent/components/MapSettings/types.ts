import { InterfaceStoredSettings } from '@/hooks/Mapper/mapRootProvider/types.ts';

export enum UserSettingsRemoteProps {
  link_signature_on_splash = 'link_signature_on_splash',
  select_on_spash = 'select_on_spash',
  delete_connection_with_sigs = 'delete_connection_with_sigs',
  bookmark_name_format = 'bookmark_name_format',
  bookmark_wormholes_start_at_zero = 'bookmark_wormholes_start_at_zero',
  bookmark_auto_copy = 'bookmark_auto_copy',
  bookmark_auto_temp_name = 'bookmark_auto_temp_name',
}

export type UserSettingsRemote = {
  link_signature_on_splash: boolean;
  select_on_spash: boolean;
  delete_connection_with_sigs: boolean;
  bookmark_name_format: string;
  bookmark_wormholes_start_at_zero: boolean;
  bookmark_auto_copy: boolean;
  bookmark_auto_temp_name: string;
};

export type UserSettings = UserSettingsRemote & InterfaceStoredSettings;

export type SettingsListItem = {
  prop: keyof UserSettings;
  label: string;
  type: 'checkbox' | 'dropdown' | 'text';
  options?: { label: string; value: string }[];
  placeholder?: string;
  helperText?: string;
};
