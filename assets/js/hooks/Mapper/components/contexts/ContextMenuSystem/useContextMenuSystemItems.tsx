import { useLabelsMenu, useStatusMenu, useTagMenu } from '@/hooks/Mapper/components/contexts/ContextMenuSystem/hooks';
import { useMemo } from 'react';
import { getSystemById } from '@/hooks/Mapper/helpers';
import classes from './ContextMenuSystem.module.scss';
import { PrimeIcons } from 'primereact/api';
import { ContextMenuSystemProps } from '@/hooks/Mapper/components/contexts';
import { useWaypointMenu } from '@/hooks/Mapper/components/contexts/hooks';
import { FastSystemActions } from '@/hooks/Mapper/components/contexts/components';

export const useContextMenuSystemItems = ({
  onDeleteSystem,
  onLockToggle,
  onHubToggle,
  onSystemTag,
  onSystemStatus,
  onSystemLabels,
  onCustomLabelDialog,
  onOpenSettings,
  onWaypointSet,
  systemId,
  hubs,
  systems,
}: Omit<ContextMenuSystemProps, 'contextMenuRef'>) => {
  const getTags = useTagMenu(systems, systemId, onSystemTag);
  const getStatus = useStatusMenu(systems, systemId, onSystemStatus);
  const getLabels = useLabelsMenu(systems, systemId, onSystemLabels, onCustomLabelDialog);
  const getWaypointMenu = useWaypointMenu(onWaypointSet);

  return useMemo(() => {
    const system = systemId ? getSystemById(systems, systemId) : undefined;

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
              systemName={system.system_static_info.solar_system_name}
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
      ...getWaypointMenu(systemId, system.system_static_info.system_class),
      {
        label: !hubs.includes(systemId) ? 'Add in Routes' : 'Remove from Routes',
        icon: PrimeIcons.MAP_MARKER,
        command: onHubToggle,
      },
      ...(system.locked
        ? [
            {
              label: 'Unlock',
              icon: PrimeIcons.LOCK_OPEN,
              command: onLockToggle,
            },
          ]
        : [
            {
              label: 'Lock',
              icon: PrimeIcons.LOCK,
              command: onLockToggle,
            },
            { separator: true },
            {
              label: 'Delete',
              icon: PrimeIcons.TRASH,
              command: onDeleteSystem,
            },
          ]),
    ];
  }, [
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
