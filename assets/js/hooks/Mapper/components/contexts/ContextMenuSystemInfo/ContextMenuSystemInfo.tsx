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

export interface ContextMenuSystemInfoProps {
  systemStatics: Map<number, SolarSystemStaticInfoRaw>;
  hubs: string[];
  contextMenuRef: RefObject<ContextMenu>;
  systemId: string | undefined;
  systems: SolarSystemRawType[];
  onOpenSettings(): void;
  onHubToggle(): void;
  onAddSystem(): void;
  onWaypointSet: WaypointSetContextHandler;
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
  hubs,
}) => {
  const getWaypointMenu = useWaypointMenu(onWaypointSet);

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
              onOpenSettings={onOpenSettings}
            />
          );
        },
      },
      { separator: true },
      ...getWaypointMenu(systemId, system.system_class),
      {
        label: !hubs.includes(systemId) ? 'Add in Routes' : 'Remove from Routes',
        icon: PrimeIcons.MAP_MARKER,
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
  }, [systemId, systemStatics, systems, getWaypointMenu, hubs, onHubToggle, onAddSystem, onOpenSettings]);

  return (
    <>
      <ContextMenu model={items} ref={contextMenuRef} breakpoint="767px" />
    </>
  );
};
