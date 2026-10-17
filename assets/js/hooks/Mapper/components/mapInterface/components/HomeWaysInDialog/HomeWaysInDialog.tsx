import { Dialog } from 'primereact/dialog';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import ReactFlow, { Background, ConnectionMode, ReactFlowProvider } from 'reactflow';
import { ContextMenu } from 'primereact/contextmenu';
import { MenuItem } from 'primereact/menuitem';
import clsx from 'clsx';

import { FastSystemActions } from '@/hooks/Mapper/components/contexts/components';
import { useJumpMenu, useWaypointMenu } from '@/hooks/Mapper/components/contexts/hooks';
import { JumpPlannerField } from '@/hooks/Mapper/components/mapRootContent/components/JumpPlanner';
import { Commands } from '@/hooks/Mapper/types/mapHandlers.ts';
import { emitMapEvent } from '@/hooks/Mapper/events';
import { WaypointSetContextHandler } from '@/hooks/Mapper/components/contexts/types.ts';
import { isWormholeSpace } from '@/hooks/Mapper/components/map/helpers/isWormholeSpace.ts';
import { getSystemStaticInfo } from '@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic';
import { OutCommand } from '@/hooks/Mapper/types';

import { MapProvider, useMapState } from '@/hooks/Mapper/components/map/MapProvider';
import { SolarSystemEdge } from '@/hooks/Mapper/components/map/components/SolarSystemEdge';
import { convertConnection2Edge, convertSystem2Node } from '@/hooks/Mapper/components/map/helpers';
import { getBehaviorForTheme } from '@/hooks/Mapper/components/map/helpers/getThemeBehavior.ts';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useLoadSystemStatic } from '@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic';
import { HomeWaysIn, KnownHome } from '@/hooks/Mapper/hooks/useKnownHomes.ts';

import classes from './HomeWaysInDialog.module.scss';

type HomeWaysInDialogProps = {
  home: KnownHome | null;
  load: (home: KnownHome) => Promise<HomeWaysIn | undefined>;
  onHide: () => void;
};

const edgeTypes = { floating: SolarSystemEdge };

// Their chain is drawn with the map's own renderer, so a system looks here exactly as it looks on
// the map it came from. The only thing added on top is which of them are the way in.
const WaysIn = ({ waysIn, onHide }: { waysIn: HomeWaysIn['ways_in']; onHide: () => void }) => {
  const {
    data: { wormholesData, effects, wormholes },
    outCommand,
  } = useMapRootState();
  const { update } = useMapState();

  const contextMenuRef = useRef<ContextMenu>(null);
  const [menuSystemId, setMenuSystemId] = useState<string | null>(null);

  // Their chain is not ours to change, so the menu carries only what makes sense on somebody
  // else's map: where a system is, and telling your own pilots to fly there.
  const onWaypointSet: WaypointSetContextHandler = useCallback(
    ({ charIds, clearWay, fromBeginning, destination }) => {
      outCommand({
        type: OutCommand.setAutopilotWaypoint,
        data: {
          character_eve_ids: charIds,
          add_to_beginning: fromBeginning,
          clear_other_waypoints: clearWay,
          destination_id: destination,
        },
      });
      setMenuSystemId(null);
    },
    [outCommand],
  );

  const getWaypointMenu = useWaypointMenu(onWaypointSet);

  // the jump planner lives behind this dialog, so it is no use opening it underneath
  const getJumpMenu = useJumpMenu({
    onJumpFrom: systemId => {
      setMenuSystemId(null);
      onHide();
      emitMapEvent({ name: Commands.showJumpPlanner, data: { field: JumpPlannerField.From, systemId } });
    },
    onJumpTo: systemId => {
      setMenuSystemId(null);
      onHide();
      emitMapEvent({ name: Commands.showJumpPlanner, data: { field: JumpPlannerField.Destination, systemId } });
    },
  });

  const menuItems = useMemo((): MenuItem[] => {
    if (!menuSystemId) {
      return [];
    }

    const staticInfo = getSystemStaticInfo(menuSystemId);

    if (!staticInfo) {
      return [];
    }

    return [
      {
        template: () => (
          <FastSystemActions
            systemId={menuSystemId}
            systemName={staticInfo.solar_system_name}
            regionName={staticInfo.region_name}
            isWH={isWormholeSpace(staticInfo.system_class)}
            onOpenSettings={() => {}}
          />
        ),
      },
      { separator: true },
      ...getWaypointMenu(menuSystemId, staticInfo.system_class),
      ...getJumpMenu(menuSystemId, staticInfo.system_class),
    ];
  }, [getJumpMenu, getWaypointMenu, menuSystemId]);

  const solarSystemIds = useMemo(() => waysIn.systems.map(system => system.id), [waysIn.systems]);
  const { loading } = useLoadSystemStatic({ systems: solarSystemIds });

  useEffect(() => {
    // the node reads a system's statics and its effect out of the map state it sits in
    update({
      systems: waysIn.systems,
      connections: waysIn.connections,
      wormholesData,
      wormholes,
      effects,
      visibleNodes: new Set(solarSystemIds),
    });
  }, [effects, solarSystemIds, update, waysIn, wormholes, wormholesData]);

  const { nodeComponent } = getBehaviorForTheme('default');
  const nodeTypes = useMemo(() => ({ custom: nodeComponent }), [nodeComponent]);

  const nodes = useMemo(
    () =>
      waysIn.systems.map(system => {
        const marker = waysIn.markers[system.id];

        return {
          ...convertSystem2Node(system),
          draggable: false,
          deletable: false,
          connectable: false,
          className: clsx({
            [classes.Home]: marker?.home,
            [classes.WayIn]: marker?.mouth && !marker?.home,
          }),
        };
      }),
    [waysIn],
  );

  const edges = useMemo(
    () => waysIn.connections.map(connection => ({ ...convertConnection2Edge(connection), selectable: false })),
    [waysIn],
  );

  if (loading) {
    return <div className="text-sm text-stone-400 p-4">Reading their map...</div>;
  }

  return (
    <>
      <ReactFlow
        nodes={nodes}
        edges={edges}
        nodeTypes={nodeTypes}
        edgeTypes={edgeTypes}
        connectionMode={ConnectionMode.Loose}
        fitView
        fitViewOptions={{ padding: 0.2 }}
        nodesDraggable={false}
        nodesConnectable={false}
        elementsSelectable={false}
        proOptions={{ hideAttribution: true }}
        onNodeContextMenu={(event, node) => {
          setMenuSystemId(node.id);
          contextMenuRef.current?.show(event);
        }}
      >
        <Background color="#292524" gap={16} />
      </ReactFlow>

      <ContextMenu className="min-w-[200px]" model={menuItems} ref={contextMenuRef} breakpoint="767px" />
    </>
  );
};

export const HomeWaysInDialog = ({ home, load, onHide }: HomeWaysInDialogProps) => {
  const { outCommand } = useMapRootState();
  const [data, setData] = useState<HomeWaysIn | undefined>();
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!home) {
      setData(undefined);
      return;
    }

    let current = true;
    setLoading(true);

    load(home)
      .then(result => {
        if (current) {
          setData(result);
        }
      })
      .finally(() => {
        if (current) {
          setLoading(false);
        }
      });

    return () => {
      current = false;
    };
  }, [home, load]);

  const hasChain = (data?.ways_in?.systems?.length ?? 0) > 0;

  return (
    <Dialog
      header={home ? `Way into ${home.map_name}` : 'Way in'}
      visible={home != null}
      draggable={false}
      resizable={false}
      style={{ width: '760px' }}
      onHide={onHide}
    >
      {home && (
        <div className="flex flex-col gap-2">
          <div className="text-xs text-stone-400">
            Their chain, cut down to what leads in - every route from a hole in k-space to the home. The home is ringed
            in white, the ways in are ringed in green. Right-click a system to send your own pilots there, or to plot a
            jump to it.
          </div>

          {loading && <div className="text-sm text-stone-400">Reading their map...</div>}

          {!loading && !hasChain && (
            <div className="text-sm text-stone-400">
              Nothing on their map leads in yet - no k-space system with a hole into the chain.
            </div>
          )}

          {!loading && hasChain && (
            <div className="h-[420px] w-full rounded border border-stone-800">
              <MapProvider onCommand={outCommand}>
                <ReactFlowProvider>
                  <WaysIn waysIn={data!.ways_in} onHide={onHide} />
                </ReactFlowProvider>
              </MapProvider>
            </div>
          )}
        </div>
      )}
    </Dialog>
  );
};
