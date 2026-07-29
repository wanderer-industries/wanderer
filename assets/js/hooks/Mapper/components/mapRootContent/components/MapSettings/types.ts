import { InterfaceStoredSettings } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { SystemLabelDefinition } from '@/hooks/Mapper/constants/labels.ts';

export { UserSettingsRemoteProps } from '@/hooks/Mapper/constants/userSettings.ts';

export type UserSettingsRemote = {
  link_signature_on_splash: boolean;
  select_on_spash: boolean;
  delete_connection_with_sigs: boolean;
  bookmark_name_format: string;
  bookmark_custom_mapping?: Record<string, string>;
  bookmark_wormholes_start_at_zero: boolean;
  bookmark_auto_copy: boolean;
  bookmark_auto_temp_name: string;
  system_auto_tag: string;
  system_custom_label_name: string;
  system_labels: SystemLabelDefinition[];
  bookmark_return_hole_ignore: boolean;
  bookmark_return_hole_symbol: string;
};

export type UserSettings = UserSettingsRemote & InterfaceStoredSettings;

export type SettingsListItem = {
  prop: keyof UserSettings;
  label: string;
  type: 'checkbox' | 'dropdown' | 'text' | 'template';
  options?: { label: string; value: string }[];
  placeholder?: string;
  helperText?: string;
  dependsOn?: keyof UserSettings;
};
