import { useCallback, useRef } from 'react';
import { PrimeIcons } from 'primereact/api';
import { MenuItem } from 'primereact/menuitem';
import { getSystemById } from '@/hooks/Mapper/helpers';
import { useMapCheckPermissions } from '@/hooks/Mapper/mapRootProvider/hooks/api';
import { SolarSystemRawType } from '@/hooks/Mapper/types';
import { UserPermission } from '@/hooks/Mapper/types/permissions.ts';

export interface UseLockMenuProps {
  systems: SolarSystemRawType[];
  systemId: string | undefined;
  onLockToggle(): void;
}

export const useLockMenu = ({ systems, systemId, onLockToggle }: UseLockMenuProps): (() => MenuItem[]) => {
  const canLockSystem = useMapCheckPermissions([UserPermission.LOCK_SYSTEM]);
  const ref = useRef({ systems, systemId, onLockToggle, canLockSystem });
  ref.current = { systems, systemId, onLockToggle, canLockSystem };

  return useCallback(() => {
    const { systems, systemId, onLockToggle, canLockSystem } = ref.current;
    const system = systemId ? getSystemById(systems, systemId) : undefined;

    if (!system || !canLockSystem) return [];

    if (!system.locked) {
      return [{ label: 'Lock', icon: PrimeIcons.LOCK, command: onLockToggle }];
    }

    return [{ label: 'Unlock', icon: PrimeIcons.LOCK_OPEN, command: onLockToggle }];
  }, []);
};
