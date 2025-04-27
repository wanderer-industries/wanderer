import { useLabelsMenu, useStatusMenu, useTagMenu } from '@/hooks/Mapper/components/contexts/ContextMenuSystem/hooks';
import { useMemo } from 'react';
import { getSystemById } from '@/hooks/Mapper/helpers';
import classes from './ContextMenuSystem.module.scss';
import { PrimeIcons } from 'primereact/api';
import { ContextMenuSystemProps } from '@/hooks/Mapper/components/contexts';
import { useWaypointMenu } from '@/hooks/Mapper/components/contexts/hooks';
import { FastSystemActions } from '@/hooks/Mapper/components/contexts/components';
import { useMapCheckPermissions } from '@/hooks/Mapper/mapRootProvider/hooks/api';
import { UserPermission } from '@/hooks/Mapper/types/permissions.ts';
import { isWormholeSpace } from '@/hooks/Mapper/components/map/helpers/isWormholeSpace.ts';
import { getSystemStaticInfo } from '@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic';
import { MapAddIcon, MapDeleteIcon, MapUserAddIcon, MapUserDeleteIcon } from '@/hooks/Mapper/icons';

export const useContextMenuSystemItems = ({
  onDeleteSystem,
  onLockToggle,
  onHubToggle,
  onUserHubToggle,
  onSystemTag,
  onSystemStatus,
  onSystemLabels,
  onCustomLabelDialog,
  onOpenSettings,
  onWaypointSet,
  systemId,
  hubs,
  userHubs,
  systems,
}: Omit<ContextMenuSystemProps, 'contextMenuRef'>) => {
  const getTags = useTagMenu(systems, systemId, onSystemTag);
  const getStatus = useStatusMenu(systems, systemId, onSystemStatus);
  const getLabels = useLabelsMenu(systems, systemId, onSystemLabels, onCustomLabelDialog);
  const getWaypointMenu = useWaypointMenu(onWaypointSet);
  const canLockSystem = useMapCheckPermissions([UserPermission.LOCK_SYSTEM]);

  return useMemo(() => {
    const system = systemId ? getSystemById(systems, systemId) : undefined;
    const systemStaticInfo = getSystemStaticInfo(systemId)!;

    if (!system || !systemId) {
      return [];
    }

    return [
      {
        className: classes.FastActions,
        template: () => {
          return (
            <FastSystemActions
              systemId={systemId}
              systemName={systemStaticInfo.solar_system_name}
              regionName={systemStaticInfo.region_name}
              isWH={isWormholeSpace(systemStaticInfo.system_class)}
              showEdit
              onOpenSettings={onOpenSettings}
            />
          );
        },
      },
      { separator: true },
      getTags(),
      getStatus(),
      ...getLabels(),
      ...getWaypointMenu(systemId, systemStaticInfo.system_class),
      {
        label: !hubs.includes(systemId) ? 'Add Route' : 'Remove Route',
        icon: !hubs.includes(systemId) ? (
          <MapAddIcon className="mr-1 relative left-[-2px]" />
        ) : (
          <MapDeleteIcon className="mr-1 relative left-[-2px]" />
        ),
        command: onHubToggle,
      },
      {
        label: !userHubs.includes(systemId) ? 'Add User Route' : 'Remove User Route',
        icon: !userHubs.includes(systemId) ? (
          <MapUserAddIcon className="mr-1 relative left-[-2px]" />
        ) : (
          <MapUserDeleteIcon className="mr-1 relative left-[-2px]" />
        ),
        command: onUserHubToggle,
      },
      ...(system.locked
        ? canLockSystem
          ? [
              {
                label: 'Unlock',
                icon: PrimeIcons.LOCK_OPEN,
                command: onLockToggle,
              },
            ]
          : []
        : [
            ...(canLockSystem
              ? [
                  {
                    label: 'Lock',
                    icon: PrimeIcons.LOCK,
                    command: onLockToggle,
                  },
                ]
              : []),
            { separator: true },
            {
              label: 'Delete',
              icon: PrimeIcons.TRASH,
              command: onDeleteSystem,
            },
          ]),
    ];
  }, [
    canLockSystem,
    systems,
    systemId,
    getTags,
    getStatus,
    getLabels,
    getWaypointMenu,
    hubs,
    onHubToggle,
    onOpenSettings,
    onLockToggle,
    onDeleteSystem,
  ]);
};
