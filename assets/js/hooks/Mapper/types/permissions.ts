export enum UserPermission {
  ADMIN_MAP = 'admin_map',
  MANAGE_MAP = 'manage_map',
  VIEW_SYSTEM = 'view_system',
  VIEW_CHARACTER = 'view_character',
  VIEW_CONNECTION = 'view_connection',
  ADD_SYSTEM = 'add_system',
  ADD_CONNECTION = 'add_connection',
  UPDATE_SYSTEM = 'update_system',
  TRACK_CHARACTER = 'track_character',
  DELETE_CONNECTION = 'delete_connection',
  DELETE_SYSTEM = 'delete_system',
  LOCK_SYSTEM = 'lock_system',
  ADD_ACL = 'add_acl',
  DELETE_ACL = 'delete_acl',
  DELETE_MAP = 'delete_map',
}

export type UserPermissions = Record<UserPermission, boolean>;
