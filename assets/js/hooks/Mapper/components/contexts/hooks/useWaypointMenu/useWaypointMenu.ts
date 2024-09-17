import { MenuItem } from 'primereact/menuitem';
import { PrimeIcons } from 'primereact/api';
import { useCallback, useRef } from 'react';
import { CharacterTypeRaw } from '@/hooks/Mapper/types';
import { useGetOwnOnlineCharacters } from '@/hooks/Mapper/components/hooks/useGetOwnOnlineCharacters.ts';
import { isKnownSpace } from '@/hooks/Mapper/components/map/helpers/isKnownSpace.ts';
import { isPochvenSpace } from '@/hooks/Mapper/components/map/helpers/isPochvenSpace.ts';
import { WaypointSetContextHandler } from '@/hooks/Mapper/components/contexts/types.ts';

const getItemsByChars = (onWaypointSet: WaypointSetContextHandler, systemId: string, chars: CharacterTypeRaw[]) => {
  return [
    {
      label: 'Set Destination',
      icon: PrimeIcons.SEND,
      command: () => {
        onWaypointSet({
          fromBeginning: true,
          clearWay: true,
          destination: systemId,
          charIds: chars.map(char => char.eve_id),
        });
      },
    },
    {
      label: 'Add Waypoint',
      icon: PrimeIcons.DIRECTIONS_ALT,
      command: () => {
        onWaypointSet({
          fromBeginning: false,
          clearWay: false,
          destination: systemId,
          charIds: chars.map(char => char.eve_id),
        });
      },
    },
    {
      label: 'Add Waypoint Front',
      icon: PrimeIcons.DIRECTIONS,
      command: () => {
        onWaypointSet({
          fromBeginning: true,
          clearWay: false,
          destination: systemId,
          charIds: chars.map(char => char.eve_id),
        });
      },
    },
  ];
};

export const useWaypointMenu = (
  onWaypointSet: WaypointSetContextHandler,
): ((systemId: string | undefined, systemClass: number) => MenuItem[]) => {
  const getOwnOnlineCharacters = useGetOwnOnlineCharacters();

  const ref = useRef({ getOwnOnlineCharacters, onWaypointSet });
  ref.current = { getOwnOnlineCharacters, onWaypointSet };

  return useCallback((systemId: string | undefined, systemClass: number) => {
    const { getOwnOnlineCharacters, onWaypointSet } = ref.current;
    if (!systemId) {
      return [];
    }

    const chars = getOwnOnlineCharacters().filter(x => x.online);

    const isSuggestedRegion = isKnownSpace(systemClass) || isPochvenSpace(systemClass);

    if (!isSuggestedRegion || chars.length === 0) {
      return [];
    }

    if (chars.length === 1) {
      return [
        {
          label: 'Waypoint',
          icon: PrimeIcons.COMPASS,
          items: getItemsByChars(onWaypointSet, systemId, chars.slice(0, 1)),
        },
      ];
    }

    return [
      {
        label: 'Waypoint',
        icon: PrimeIcons.COMPASS,
        items: [
          {
            label: 'All',
            icon: PrimeIcons.USERS,
            items: getItemsByChars(onWaypointSet, systemId, chars),
          },
          ...chars.map(char => ({
            label: char.name,
            icon: PrimeIcons.USER,
            items: getItemsByChars(onWaypointSet, systemId, [char]),
          })),
        ],
      },
    ];
  }, []);
};
