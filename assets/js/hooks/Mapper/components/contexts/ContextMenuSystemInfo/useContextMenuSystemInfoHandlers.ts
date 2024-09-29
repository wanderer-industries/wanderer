import { RefObject, useCallback, useRef, useState } from 'react';
import { ContextMenu } from 'primereact/contextmenu';
import { Commands, MapHandlers, OutCommand, OutCommandHandler } from '@/hooks/Mapper/types/mapHandlers.ts';
import { WaypointSetContextHandler } from '@/hooks/Mapper/components/contexts/types.ts';
import { ctxManager } from '@/hooks/Mapper/utils/contextManager.ts';
import * as React from 'react';
import { SolarSystemStaticInfoRaw } from '@/hooks/Mapper/types';

interface UseContextMenuSystemHandlersProps {
  hubs: string[];
  outCommand: OutCommandHandler;
  mapRef: RefObject<MapHandlers>;
}

export const useContextMenuSystemInfoHandlers = ({ hubs, outCommand, mapRef }: UseContextMenuSystemHandlersProps) => {
  const contextMenuRef = useRef<ContextMenu | null>(null);

  const [system, setSystem] = useState<string>();
  const routeRef = useRef<(SolarSystemStaticInfoRaw | undefined)[]>([]);

  const ref = useRef({ hubs, system, outCommand, mapRef });
  ref.current = { hubs, system, outCommand, mapRef };

  const open = useCallback(
    (ev: React.SyntheticEvent, systemId: string, route: (SolarSystemStaticInfoRaw | undefined)[]) => {
      setSystem(systemId);
      routeRef.current = route;
      ev.preventDefault();
      ctxManager.next('ctxSysInfo', contextMenuRef.current);
      contextMenuRef.current?.show(ev);
    },
    [],
  );

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

  const onAddSystem = useCallback(() => {
    const { system, outCommand, mapRef } = ref.current;
    if (!system) {
      return;
    }

    outCommand({
      type: OutCommand.addSystem,
      data: {
        system_id: system,
      },
    });
    setTimeout(() => {
      mapRef.current?.command(Commands.selectSystem, system);
      setSystem(undefined);
    }, 200);
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
    onAddSystem,
    onHubToggle,
    onOpenSettings,
    onWaypointSet,
    systemId: system,
  };
};
