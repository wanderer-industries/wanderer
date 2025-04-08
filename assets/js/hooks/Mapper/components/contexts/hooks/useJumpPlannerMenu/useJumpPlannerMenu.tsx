import { MenuItem } from 'primereact/menuitem';
import { PrimeIcons } from 'primereact/api';
import { useCallback } from 'react';
import { isPossibleSpace } from '@/hooks/Mapper/components/map/helpers/isKnownSpace.ts';
import { Route } from '@/hooks/Mapper/types/routes.ts';
import { SolarSystemRawType, SolarSystemStaticInfoRaw } from '@/hooks/Mapper/types';
import { SOLAR_SYSTEM_CLASS_IDS } from '@/hooks/Mapper/components/map/constants.ts';
import { getSystemStaticInfo } from '@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic';

const imperialSpace = [SOLAR_SYSTEM_CLASS_IDS.hs, SOLAR_SYSTEM_CLASS_IDS.ls, SOLAR_SYSTEM_CLASS_IDS.ns];
const criminalSpace = [SOLAR_SYSTEM_CLASS_IDS.ls, SOLAR_SYSTEM_CLASS_IDS.ns];

enum JUMP_SHIP_TYPE {
  BLACK_OPS = 'Marshal',
  JUMP_FREIGHTER = 'Anshar',
  RORQUAL = 'Rorqual',
  CAPITAL = 'Thanatos',
  SUPER_CAPITAL = 'Avatar',
}

export const openJumpPlan = (jumpShipType: JUMP_SHIP_TYPE, from: string, to: string) => {
  return window.open(`https://evemaps.dotlan.net/jump/${jumpShipType},544/${from}:${to}`, '_blank');
};

const BRACKET_ICONS = {
  npcsuperCarrier_32: '/icons/brackets/npcsuperCarrier_32.png',
  carrier_32: '/icons/brackets/carrier_32.png',
  battleship_32: '/icons/brackets/battleship_32.png',
  freighter_32: '/icons/brackets/freighter_32.png',
};

const renderIcon = (icon: string) => {
  return (
    <div className="flex justify-center items-center mr-1.5 pt-px">
      <img src={icon} style={{ width: 20, height: 20 }} />
    </div>
  );
};

export const useJumpPlannerMenu = (
  systems: SolarSystemRawType[],
  systemIdFrom?: string | undefined,
): ((systemId: SolarSystemStaticInfoRaw, routes: Route[]) => MenuItem[]) => {
  return useCallback(
    (destination: SolarSystemStaticInfoRaw) => {
      if (!destination || !systemIdFrom) {
        return [];
      }

      const origin = getSystemStaticInfo(systemIdFrom);

      if (!origin) {
        return [];
      }

      const isShowBOorJumpFreighter =
        isPossibleSpace(imperialSpace, origin.system_class) && isPossibleSpace(criminalSpace, destination.system_class);

      const isShowCapital =
        isPossibleSpace(criminalSpace, origin.system_class) && isPossibleSpace(criminalSpace, destination.system_class);

      if (!isShowBOorJumpFreighter && !isShowCapital) {
        return [];
      }

      return [
        {
          label: 'In Jump Planner',
          icon: PrimeIcons.SEND,
          items: [
            ...(isShowBOorJumpFreighter
              ? [
                  {
                    label: 'Black Ops',
                    icon: renderIcon(BRACKET_ICONS.battleship_32),
                    command: () => {
                      openJumpPlan(JUMP_SHIP_TYPE.BLACK_OPS, origin.solar_system_name, destination.solar_system_name);
                    },
                  },
                  {
                    label: 'Jump Freighter',
                    icon: renderIcon(BRACKET_ICONS.freighter_32),
                    command: () => {
                      openJumpPlan(
                        JUMP_SHIP_TYPE.JUMP_FREIGHTER,
                        origin.solar_system_name,
                        destination.solar_system_name,
                      );
                    },
                  },
                  {
                    label: 'Rorqual',
                    icon: renderIcon(BRACKET_ICONS.freighter_32),
                    command: () => {
                      openJumpPlan(JUMP_SHIP_TYPE.RORQUAL, origin.solar_system_name, destination.solar_system_name);
                    },
                  },
                ]
              : []),

            ...(isShowCapital
              ? [
                  {
                    label: 'Capital',
                    icon: renderIcon(BRACKET_ICONS.carrier_32),
                    command: () => {
                      openJumpPlan(JUMP_SHIP_TYPE.CAPITAL, origin.solar_system_name, destination.solar_system_name);
                    },
                  },
                  {
                    label: 'Super Capital',
                    icon: renderIcon(BRACKET_ICONS.npcsuperCarrier_32),
                    command: () => {
                      openJumpPlan(
                        JUMP_SHIP_TYPE.SUPER_CAPITAL,
                        origin.solar_system_name,
                        destination.solar_system_name,
                      );
                    },
                  },
                ]
              : []),
          ],
        },
      ];
    },
    [systems, systemIdFrom],
  );
};
