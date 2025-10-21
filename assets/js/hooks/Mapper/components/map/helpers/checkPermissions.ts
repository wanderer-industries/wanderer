import { UserPermission, UserPermissions } from '@/hooks/Mapper/types';

export const checkPermissions = (permissions: Partial<UserPermissions>, targetPermission: UserPermission) => {
  return targetPermission != null && permissions[targetPermission];
};
