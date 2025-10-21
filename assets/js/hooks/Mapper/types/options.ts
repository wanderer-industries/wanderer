import { UserPermission } from '@/hooks/Mapper/types/permissions.ts';

export type StringBoolean = 'true' | 'false';

export type MapOptions = {
  allowed_copy_for: UserPermission;
  allowed_paste_for: UserPermission;
  layout: string;
  restrict_offline_showing: StringBoolean;
  show_linked_signature_id: StringBoolean;
  show_linked_signature_id_temp_name: StringBoolean;
  show_temp_system_name: StringBoolean;
  store_custom_labels: StringBoolean;
};
