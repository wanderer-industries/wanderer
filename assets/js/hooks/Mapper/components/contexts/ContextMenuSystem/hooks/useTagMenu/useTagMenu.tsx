import { MenuItem } from 'primereact/menuitem';
import { PrimeIcons } from 'primereact/api';
import { useCallback, useRef } from 'react';
import { SolarSystemRawType } from '@/hooks/Mapper/types';
import { getSystemById } from '@/hooks/Mapper/helpers';
import clsx from 'clsx';
import { GRADIENT_MENU_ACTIVE_CLASSES } from '@/hooks/Mapper/constants.ts';
import { LayoutEventBlocker, WdButton } from '@/hooks/Mapper/components/ui-kit';

const AVAILABLE_TAGS = [
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'X',
  'Y',
  'Z',
  '0',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
];

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

    const isSelectedTag = AVAILABLE_TAGS.includes(system?.tag ?? '');

    const menuItem: MenuItem = {
      label: 'Tag',
      icon: PrimeIcons.HASHTAG,
      className: clsx({ [GRADIENT_MENU_ACTIVE_CLASSES]: isSelectedTag }),
      items: [
        {
          label: 'Digit',
          icon: PrimeIcons.TAGS,
          className: '!h-[128px] suppress-menu-behaviour',
          template: () => {
            return (
              <LayoutEventBlocker className="flex flex-col gap-1 w-[200px] h-full px-2">
                <div className="grid grid-cols-[auto_auto_auto_auto_auto_auto] gap-1">
                  {AVAILABLE_TAGS.map(x => (
                    <WdButton
                      outlined={system?.tag !== x}
                      severity="warning"
                      key={x}
                      value={x}
                      size="small"
                      className="p-[3px] justify-center"
                      onClick={() => system?.tag !== x && onSystemTag(x)}
                    >
                      {x}
                    </WdButton>
                  ))}
                  <WdButton
                    disabled={!isSelectedTag}
                    icon="pi pi-ban"
                    size="small"
                    className="!p-0 !w-[initial] justify-center"
                    outlined
                    severity="help"
                    onClick={() => onSystemTag()}
                  ></WdButton>
                </div>
              </LayoutEventBlocker>
            );
          },
        },
      ],
    };

    return menuItem;
  }, []);
};
