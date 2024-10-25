import { MenuItem } from 'primereact/menuitem';
import { PrimeIcons } from 'primereact/api';
import { useCallback, useRef } from 'react';
import { SolarSystemRawType } from '@/hooks/Mapper/types';
import { getSystemById } from '@/hooks/Mapper/helpers';
import clsx from 'clsx';
import { GRADIENT_MENU_ACTIVE_CLASSES } from '@/hooks/Mapper/constants.ts';

const AVAILABLE_LETTERS = ['A', 'B', 'C', 'D', 'E', 'F', 'X', 'Y', 'Z'];
const AVAILABLE_NUMBERS = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

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

    const isSelectedLetters = AVAILABLE_LETTERS.includes(system?.tag ?? '');
    const isSelectedNumbers = AVAILABLE_NUMBERS.includes(system?.tag ?? '');

    const menuItem: MenuItem = {
      label: 'Tag',
      icon: PrimeIcons.HASHTAG,
      className: clsx({ [GRADIENT_MENU_ACTIVE_CLASSES]: isSelectedLetters || isSelectedNumbers }),
      items: [
        ...(system?.tag !== '' && system?.tag !== null
          ? [
              {
                label: 'Clear',
                icon: PrimeIcons.BAN,
                command: () => onSystemTag(),
              },
            ]
          : []),
        {
          label: 'Letter',
          icon: PrimeIcons.TAGS,
          className: clsx({ [GRADIENT_MENU_ACTIVE_CLASSES]: isSelectedLetters }),
          items: AVAILABLE_LETTERS.map(x => ({
            label: x,
            icon: PrimeIcons.TAG,
            command: () => onSystemTag(x),
            className: clsx({ [GRADIENT_MENU_ACTIVE_CLASSES]: system?.tag === x }),
          })),
        },
        {
          label: 'Digit',
          icon: PrimeIcons.TAGS,
          className: clsx({ [GRADIENT_MENU_ACTIVE_CLASSES]: isSelectedNumbers }),
          items: AVAILABLE_NUMBERS.map(x => ({
            label: x,
            icon: PrimeIcons.TAG,
            command: () => onSystemTag(x),
            className: clsx({ [GRADIENT_MENU_ACTIVE_CLASSES]: system?.tag === x }),
          })),
        },
      ],
    };

    return menuItem;
  }, []);
};
