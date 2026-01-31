import React, { RefObject, useCallback, useMemo } from 'react';
import { ContextMenu } from 'primereact/contextmenu';
import { PrimeIcons } from 'primereact/api';
import { MenuItem } from 'primereact/menuitem';
import { CharacterTypeRaw, SolarSystemRawType, SolarSystemStaticInfoRaw } from '@/hooks/Mapper/types';
import classes from './ContextMenuSystemInfo.module.scss';
import { getSystemById } from '@/hooks/Mapper/helpers';
import { useWaypointMenu } from '@/hooks/Mapper/components/contexts/hooks';
import { WaypointSetContextHandler } from '@/hooks/Mapper/components/contexts/types.ts';
import { FastSystemActions } from '@/hooks/Mapper/components/contexts/components';
import { useJumpPlannerMenu } from '@/hooks/Mapper/components/contexts/hooks';
import { Route, RouteStationSummary } from '@/hooks/Mapper/types/routes.ts';
import { isWormholeSpace } from '@/hooks/Mapper/components/map/helpers/isWormholeSpace.ts';
import { MapAddIcon, MapDeleteIcon } from '@/hooks/Mapper/icons';
import { useRouteProvider } from '@/hooks/Mapper/components/mapInterface/widgets/RoutesWidget/RoutesProvider.tsx';
import { useGetOwnOnlineCharacters } from '@/hooks/Mapper/components/hooks/useGetOwnOnlineCharacters.ts';

export interface ContextMenuSystemInfoProps {
  systemStatics: Map<number, SolarSystemStaticInfoRaw>;
  contextMenuRef: RefObject<ContextMenu>;
  systemId: string | undefined;
  systemIdFrom?: string | undefined;
  systems: SolarSystemRawType[];
  onOpenSettings(): void;
  onHubToggle(): void;
  onAddSystem(): void;
  onWaypointSet: WaypointSetContextHandler;
  routes: Route[];
}

export const ContextMenuSystemInfo: React.FC<ContextMenuSystemInfoProps> = ({
  systems,
  systemStatics,
  contextMenuRef,
  onHubToggle,
  onOpenSettings,
  onAddSystem,
  onWaypointSet,
  systemId,
  systemIdFrom,
  routes,
}) => {
  const getWaypointMenu = useWaypointMenu(onWaypointSet);
  const getJumpPlannerMenu = useJumpPlannerMenu(systems, systemIdFrom);
  const { toggleHubCommand, hubs } = useRouteProvider();
  const getOwnOnlineCharacters = useGetOwnOnlineCharacters();

  const getStationWaypointItems = useCallback(
    (destinationId: string, chars: CharacterTypeRaw[]): MenuItem[] => [
      {
        label: 'Set Destination',
        icon: PrimeIcons.SEND,
        command: () => {
          onWaypointSet({
            fromBeginning: true,
            clearWay: true,
            destination: destinationId,
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
            destination: destinationId,
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
            destination: destinationId,
            charIds: chars.map(char => char.eve_id),
          });
        },
      },
    ],
    [onWaypointSet],
  );

  const getStationsMenu = useCallback(
    (stations: RouteStationSummary[]) => {
      const chars = getOwnOnlineCharacters().filter(x => x.online);
      if (chars.length === 0) {
        return [
          {
            label: 'Stations',
            icon: PrimeIcons.MAP_MARKER,
            items: [{ label: 'No online characters', disabled: true }],
          },
        ];
      }

      return [
        {
          label: 'Stations',
          icon: PrimeIcons.MAP_MARKER,
          items: stations.map(station => {
            const destinationId = station.station_id.toString();

            if (chars.length === 1) {
              return {
                label: station.station_name,
                items: getStationWaypointItems(destinationId, chars.slice(0, 1)),
              };
            }

            return {
              label: station.station_name,
              className: 'w-[500px]',
              items: [
                {
                  label: 'All',
                  icon: PrimeIcons.USERS,
                  items: getStationWaypointItems(destinationId, chars),
                },
                ...chars.map(char => ({
                  label: char.name,
                  icon: PrimeIcons.USER,
                  items: getStationWaypointItems(destinationId, [char]),
                })),
              ],
            };
          }),
        },
      ];
    },
    [getOwnOnlineCharacters, getStationWaypointItems],
  );

  const items: MenuItem[] = useMemo(() => {
    const system = systemId ? systemStatics.get(parseInt(systemId)) : undefined;
    const systemOnMap = systemId ? getSystemById(systems, systemId) : undefined;

    if (!systemId || !system) {
      return [];
    }

    const route = routes.find(x => x.destination?.toString() === systemId);
    const stationItems = route?.stations?.length ? getStationsMenu(route.stations) : [];

    return [
      {
        className: classes.FastActions,
        template: () => {
          return (
            <FastSystemActions
              systemId={systemId}
              systemName={system.solar_system_name}
              regionName={system.region_name}
              isWH={isWormholeSpace(system.system_class)}
              onOpenSettings={onOpenSettings}
            />
          );
        },
      },

      { separator: true },
      ...getJumpPlannerMenu(system, routes),
      ...getWaypointMenu(systemId, system.system_class),
      ...stationItems,
      ...(toggleHubCommand
        ? [
            {
              label: !hubs.includes(systemId) ? 'Add Route' : 'Remove Route',
              icon: !hubs.includes(systemId) ? (
                <MapAddIcon className="mr-1 relative left-[-2px]" />
              ) : (
                <MapDeleteIcon className="mr-1 relative left-[-2px]" />
              ),
              command: onHubToggle,
            },
          ]
        : []),
      ...(!systemOnMap
        ? [
            {
              label: 'Add to map',
              icon: PrimeIcons.PLUS,
              command: onAddSystem,
            },
          ]
        : []),
    ];
  }, [
    systemId,
    systemStatics,
    systems,
    getJumpPlannerMenu,
    getWaypointMenu,
    getStationsMenu,
    hubs,
    onHubToggle,
    onAddSystem,
    onOpenSettings,
    toggleHubCommand,
    routes,
  ]);

  return (
    <>
      <ContextMenu className={classes.ContextMenu} model={items} ref={contextMenuRef} breakpoint="767px" />
    </>
  );
};
