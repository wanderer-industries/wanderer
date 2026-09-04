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
  intel_source_map_id?: string | null;
  /**
   * Solar system ids whose intel is owned by the source map. Only these are
   * read-only — a system the source map has no data for is still editable here.
   */
  intel_inherited_system_ids?: number[];
};
