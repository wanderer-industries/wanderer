import {
  useLabelsMenu,
  useStatusMenu,
  useTagMenu,
  useUserRoute,
} from '@/hooks/Mapper/components/contexts/ContextMenuSystem/hooks';
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
import { MapAddIcon, MapDeleteIcon } from '@/hooks/Mapper/icons';
import { PingType } from '@/hooks/Mapper/types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import clsx from 'clsx';
import { MenuItem } from 'primereact/menuitem';
import { MenuItemWithInfo, WdMenuItem } from '@/hooks/Mapper/components/ui-kit';

export const useContextMenuSystemItems = ({
  onDeleteSystem,
  onLockToggle,
  onHubToggle,
  onUserHubToggle,
  onTogglePing,
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
  const canManageSystem = useMapCheckPermissions([UserPermission.UPDATE_SYSTEM]);
  const canDeleteSystem = useMapCheckPermissions([UserPermission.DELETE_SYSTEM]);
  const getUserRoutes = useUserRoute({ userHubs, systemId, onUserHubToggle });

  const {
    data: { pings, isSubscriptionActive },
  } = useMapRootState();

  const ping = useMemo(() => (pings.length === 1 ? pings[0] : undefined), [pings]);
  const isShowPingBtn = useMemo(() => {
    if (!isSubscriptionActive) {
      return false;
    }

    if (pings.length === 0) {
      return true;
    }

    return pings[0].solar_system_id === systemId;
  }, [isSubscriptionActive, pings, systemId]);

  return useMemo((): MenuItem[] => {
    const system = systemId ? getSystemById(systems, systemId) : undefined;
    const systemStaticInfo = getSystemStaticInfo(systemId)!;

    const hasPing = ping?.solar_system_id === systemId;

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
      ...getUserRoutes(),

      { separator: true },
      {
        command: () => onTogglePing(PingType.Rally, systemId, ping?.id, hasPing),
        disabled: !isShowPingBtn,
        template: () => {
          const iconClasses = clsx({
            'pi text-cyan-400 hero-signal': !hasPing,
            'pi text-red-400 hero-signal-slash': hasPing,
          });

          if (isShowPingBtn) {
            return <WdMenuItem icon={iconClasses}>{!hasPing ? 'Ping: RALLY' : 'Cancel: RALLY'}</WdMenuItem>;
          }

          return (
            <MenuItemWithInfo
              infoTitle="Locked. Ping can be set only for one system."
              infoClass="pi-lock text-stone-500 mr-[12px]"
            >
              <WdMenuItem disabled icon={iconClasses}>
                {!hasPing ? 'Ping: RALLY' : 'Cancel: RALLY'}
              </WdMenuItem>
            </MenuItemWithInfo>
          );
        },
      },
      ...(system.locked && canLockSystem
        ? [
            {
              label: 'Unlock',
              icon: PrimeIcons.LOCK_OPEN,
              command: onLockToggle,
            },
          ]
        : []),
      ...(!system.locked && canManageSystem
        ? [
            {
              label: 'Lock',
              icon: PrimeIcons.LOCK,
              command: onLockToggle,
            },
          ]
        : []),

      ...(canDeleteSystem && !system.locked
        ? [
            { separator: true },
            {
              command: onDeleteSystem,
              disabled: hasPing,
              template: () => {
                if (!hasPing) {
                  return <WdMenuItem icon="text-red-400 pi pi-trash">Delete</WdMenuItem>;
                }

                return (
                  <MenuItemWithInfo
                    infoTitle="Locked. System can not be deleted until ping set."
                    infoClass="pi-lock text-stone-500 mr-[12px]"
                  >
                    <WdMenuItem disabled icon="text-red-400 pi pi-trash">
                      Delete
                    </WdMenuItem>
                  </MenuItemWithInfo>
                );
              },
            },
          ]
        : []),
    ];
  }, [
    systemId,
    systems,
    getTags,
    getStatus,
    getLabels,
    getWaypointMenu,
    getUserRoutes,
    hubs,
    onHubToggle,
    canLockSystem,
    onLockToggle,
    canDeleteSystem,
    onDeleteSystem,
    onOpenSettings,
    onTogglePing,
    ping,
    isShowPingBtn,
  ]);
};
