import { useCallback, useRef, useState } from 'react';
import { ContextMenu } from 'primereact/contextmenu';
import { OutCommand, OutCommandHandler } from '@/hooks/Mapper/types/mapHandlers.ts';
import { SolarSystemRawType } from '@/hooks/Mapper/types';
import { WaypointSetContextHandler } from '@/hooks/Mapper/components/contexts/types.ts';
import { ctxManager } from '@/hooks/Mapper/utils/contextManager.ts';
import { useDeleteSystems } from '@/hooks/Mapper/components/contexts/hooks';
// import { PingType } from '@/hooks/Mapper/types/ping.ts';

interface UseContextMenuSystemHandlersProps {
  hubs: string[];
  userHubs: string[];
  systems: SolarSystemRawType[];
  outCommand: OutCommandHandler;
}

export const useContextMenuSystemHandlers = ({
  systems,
  hubs,
  userHubs,
  outCommand,
}: UseContextMenuSystemHandlersProps) => {
  const contextMenuRef = useRef<ContextMenu | null>(null);

  const [system, setSystem] = useState<string>();

  const { deleteSystems } = useDeleteSystems();

  const ref = useRef({ hubs, userHubs, system, systems, outCommand, deleteSystems });
  ref.current = { hubs, userHubs, system, systems, outCommand, deleteSystems };

  const open = useCallback((ev: any, systemId: string) => {
    setSystem(systemId);
    ev.preventDefault();
    ctxManager.next('ctxSys', contextMenuRef.current);
    contextMenuRef.current?.show(ev);
  }, []);

  const onDeleteSystem = useCallback(() => {
    const { system, deleteSystems } = ref.current;
    if (!system) {
      return;
    }

    deleteSystems([system]);
    setSystem(undefined);
  }, []);

  const onLockToggle = useCallback(() => {
    const { system, systems, outCommand } = ref.current;
    if (!system) {
      return;
    }

    const sysInfo = systems.find(x => x.id === system)!;

    outCommand({
      type: OutCommand.updateSystemLocked,
      data: {
        system_id: system,
        value: !sysInfo.locked,
      },
    });
    setSystem(undefined);
  }, []);

  const onHubToggle = useCallback(() => {
    const { hubs, system, outCommand } = ref.current;
    if (!system) {
      return;
    }

    outCommand({
      type: !hubs.includes(system) ? OutCommand.addHub : OutCommand.deleteHub,
      data: {
        system_id: system,
      },
    });
    setSystem(undefined);
  }, []);

  const onUserHubToggle = useCallback(() => {
    const { userHubs, system, outCommand } = ref.current;
    if (!system) {
      return;
    }

    outCommand({
      type: !userHubs.includes(system) ? OutCommand.addUserHub : OutCommand.deleteUserHub,
      data: {
        system_id: system,
      },
    });
    setSystem(undefined);
  }, []);

  // const onTogglePingRally = useCallback(() => {
  //   const { userHubs, system, outCommand } = ref.current;
  //   if (!system) {
  //     return;
  //   }
  //
  //   outCommand({
  //     type: OutCommand.openPing,
  //     data: {
  //       solar_system_id: system,
  //       type: PingType.Rally,
  //     },
  //   });
  //   setSystem(undefined);
  // }, []);

  const onSystemTag = useCallback((tag?: string) => {
    const { system, outCommand } = ref.current;
    if (!system) {
      return;
    }

    outCommand({
      type: OutCommand.updateSystemTag,
      data: {
        system_id: system,
        value: tag ?? '',
      },
    });
    setSystem(undefined);
  }, []);

  const onSystemTemporaryName = useCallback((temporaryName?: string) => {
    const { system, outCommand } = ref.current;
    if (!system) {
      return;
    }

    outCommand({
      type: OutCommand.updateSystemTemporaryName,
      data: {
        system_id: system,
        value: temporaryName ?? '',
      },
    });
    setSystem(undefined);
  }, []);

  const onSystemStatus = useCallback((status: number) => {
    const { system, outCommand } = ref.current;
    if (!system) {
      return;
    }

    outCommand({
      type: OutCommand.updateSystemStatus,
      data: {
        system_id: system,
        value: status,
      },
    });
    setSystem(undefined);
  }, []);

  const onSystemLabels = useCallback((labels: string) => {
    const { system, outCommand } = ref.current;
    if (!system) {
      return;
    }

    outCommand({
      type: OutCommand.updateSystemLabels,
      data: {
        system_id: system,
        value: labels,
      },
    });
    setSystem(undefined);
  }, []);

  const onOpenSettings = useCallback(() => {
    const { system, outCommand } = ref.current;
    if (!system) {
      return;
    }

    outCommand({
      type: OutCommand.openSettings,
      data: {
        system_id: system,
      },
    });
    setSystem(undefined);
  }, []);

  const onWaypointSet: WaypointSetContextHandler = useCallback(({ charIds, clearWay, fromBeginning, destination }) => {
    const { system, outCommand } = ref.current;
    if (!system) {
      return;
    }

    outCommand({
      type: OutCommand.setAutopilotWaypoint,
      data: {
        character_eve_ids: charIds,
        add_to_beginning: fromBeginning,
        clear_other_waypoints: clearWay,
        destination_id: destination,
      },
    });
    setSystem(undefined);
  }, []);

  return {
    open,

    contextMenuRef,
    onDeleteSystem,
    onLockToggle,
    onHubToggle,
    onUserHubToggle,
    // onTogglePingRally,
    onSystemTag,
    onSystemTemporaryName,
    onSystemStatus,
    onSystemLabels,
    onOpenSettings,
    onWaypointSet,
    systemId: system,
  };
};
