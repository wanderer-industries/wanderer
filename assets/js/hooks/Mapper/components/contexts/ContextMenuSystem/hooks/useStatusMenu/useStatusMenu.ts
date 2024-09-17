import { MenuItem } from 'primereact/menuitem';
import { PrimeIcons } from 'primereact/api';
import { useCallback, useRef } from 'react';
import { SolarSystemRawType } from '@/hooks/Mapper/types';
import { getSystemById } from '@/hooks/Mapper/helpers';
import clsx from 'clsx';
import { STATUS_COLOR_CLASSES, STATUS_NAMES, STATUSES_ORDER } from '@/hooks/Mapper/components/map/constants.ts';
import { GRADIENT_MENU_ACTIVE_CLASSES } from '@/hooks/Mapper/constants.ts';

export const useStatusMenu = (
  systems: SolarSystemRawType[],
  systemId: string | undefined,
  onSystemStatus: (val: number) => void,
): (() => MenuItem) => {
  const ref = useRef({ onSystemStatus, systemId, systems });
  ref.current = { onSystemStatus, systemId, systems };

  return useCallback(() => {
    const { onSystemStatus, systemId, systems } = ref.current;
    const system = systemId ? getSystemById(systems, systemId) : undefined;

    if (!system) {
      return {
        label: 'Status',
        icon: PrimeIcons.BOLT,
        items: [],
      };
    }

    const isSelectedStatus = system.status;
    const statusList = system.status ? STATUSES_ORDER : STATUSES_ORDER.slice(1);

    const menuItem: MenuItem = {
      label: 'Status',
      icon: PrimeIcons.BOLT,
      className: clsx({ [GRADIENT_MENU_ACTIVE_CLASSES]: isSelectedStatus }),
      items: statusList.map(x => ({
        label: STATUS_NAMES[x],
        icon: x !== 0 ? `${PrimeIcons.BOLT} ${STATUS_COLOR_CLASSES[x]}` : PrimeIcons.BAN,
        command: () => onSystemStatus(x),
        className: clsx({ [GRADIENT_MENU_ACTIVE_CLASSES]: x === system.status }),
      })),
    };

    return menuItem;
  }, []);
};
