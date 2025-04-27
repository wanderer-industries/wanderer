import React, { RefObject, useMemo } from 'react';
import { ContextMenu } from 'primereact/contextmenu';
import { PrimeIcons } from 'primereact/api';
import { MenuItem } from 'primereact/menuitem';
import { SolarSystemRawType, SolarSystemStaticInfoRaw } from '@/hooks/Mapper/types';
import classes from './ContextMenuSystemInfo.module.scss';
import { getSystemById } from '@/hooks/Mapper/helpers';
import { useWaypointMenu } from '@/hooks/Mapper/components/contexts/hooks';
import { WaypointSetContextHandler } from '@/hooks/Mapper/components/contexts/types.ts';
import { FastSystemActions } from '@/hooks/Mapper/components/contexts/components';
import { useJumpPlannerMenu } from '@/hooks/Mapper/components/contexts/hooks';
import { Route } from '@/hooks/Mapper/types/routes.ts';
import { isWormholeSpace } from '@/hooks/Mapper/components/map/helpers/isWormholeSpace.ts';
import { MapAddIcon, MapDeleteIcon } from '@/hooks/Mapper/icons';

export interface ContextMenuSystemInfoProps {
  systemStatics: Map<number, SolarSystemStaticInfoRaw>;
  hubs: string[];
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
  hubs,
  routes,
}) => {
  const getWaypointMenu = useWaypointMenu(onWaypointSet);
  const getJumpPlannerMenu = useJumpPlannerMenu(systems, systemIdFrom);

  const items: MenuItem[] = useMemo(() => {
    const system = systemId ? systemStatics.get(parseInt(systemId)) : undefined;
    const systemOnMap = systemId ? getSystemById(systems, systemId) : undefined;

    if (!systemId || !system) {
      return [];
    }
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
      {
        label: !hubs.includes(systemId) ? 'Add Route' : 'Remove Route',
        icon: !hubs.includes(systemId) ? (
          <MapAddIcon className="mr-1 relative left-[-2px]" />
        ) : (
          <MapDeleteIcon className="mr-1 relative left-[-2px]" />
        ),
        command: onHubToggle,
      },
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
    hubs,
    onHubToggle,
    onAddSystem,
    onOpenSettings,
  ]);

  return (
    <>
      <ContextMenu model={items} ref={contextMenuRef} breakpoint="767px" />
    </>
  );
};
