import { useMemo } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { UserPermission } from '@/hooks/Mapper/types/permissions.ts';

export const useMapCheckPermissions = (permissions: UserPermission[]) => {
  const {
    data: { userPermissions },
  } = useMapRootState();

  return useMemo(() => permissions.every(x => userPermissions[x]), [permissions, userPermissions]);
};
