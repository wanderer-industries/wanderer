import { InterfaceStoredSettings } from '@/hooks/Mapper/mapRootProvider/types.ts';

export enum UserSettingsRemoteProps {
  link_signature_on_splash = 'link_signature_on_splash',
  select_on_spash = 'select_on_spash',
  delete_connection_with_sigs = 'delete_connection_with_sigs',
}

export type UserSettingsRemote = {
  link_signature_on_splash: boolean;
  select_on_spash: boolean;
  delete_connection_with_sigs: boolean;
};

export type UserSettings = UserSettingsRemote & InterfaceStoredSettings;

export type SettingsListItem = {
  prop: keyof UserSettings;
  label: string;
  type: 'checkbox' | 'dropdown';
  options?: { label: string; value: string }[];
};
