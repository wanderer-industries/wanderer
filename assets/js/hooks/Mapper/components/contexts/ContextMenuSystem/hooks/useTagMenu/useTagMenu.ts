import { MenuItem } from 'primereact/menuitem';
import { PrimeIcons } from 'primereact/api';
import { useCallback, useRef } from 'react';
import { SolarSystemRawType } from '@/hooks/Mapper/types';
import { getSystemById } from '@/hooks/Mapper/helpers';
import clsx from 'clsx';
import { GRADIENT_MENU_ACTIVE_CLASSES } from '@/hooks/Mapper/constants.ts';

// We only keep numbers for 'occupied'
const AVAILABLE_NUMBERS = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10+'];

export const useTagMenu = (
  systems: SolarSystemRawType[],
  systemId: string | undefined,
  onSystemTag: (val?: string) => void,
): (() => MenuItem) => {
  const ref = useRef({ onSystemTag, systems, systemId });
  ref.current = { onSystemTag, systems, systemId };

  return useCallback(() => {
    const { onSystemTag, systemId, systems } = ref.current;
    const system = systemId ? getSystemById(systems, systemId) : undefined;

    // Check if the current 'occupied' value is in our available list
    const isSelectedOccupied = AVAILABLE_NUMBERS.includes(system?.tag ?? '');

    const menuItem: MenuItem = {
      label: 'Occupied',
      icon: PrimeIcons.HASHTAG,
      className: clsx({ [GRADIENT_MENU_ACTIVE_CLASSES]: isSelectedOccupied }),
      items: [
        // Show "Clear" only if there's an occupied value
        ...(system?.tag
          ? [
              {
                label: 'Clear',
                icon: PrimeIcons.BAN,
                command: () => onSystemTag(),
              },
            ]
          : []),

        // Flatten the list of numbers on the same level
        ...AVAILABLE_NUMBERS.map((num) => ({
          label: num,
          icon: PrimeIcons.USER,
          command: () => onSystemTag(num),
          className: clsx({
            [GRADIENT_MENU_ACTIVE_CLASSES]: system?.tag === num,
          }),
        })),
      ],
    };

    return menuItem;
  }, []);
};
