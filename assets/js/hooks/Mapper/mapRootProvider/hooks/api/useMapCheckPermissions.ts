import { useCallback } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { UserPermission } from '@/hooks/Mapper/types/permissions.ts';

export const useMapCheckPermissions = () => {
  const {
    data: { userPermissions },
  } = useMapRootState();

  return useCallback((permissions: UserPermission[]) => permissions.every(x => userPermissions[x]), [userPermissions]);
};
