import { NodeSelectionMouseHandler } from '@/hooks/Mapper/components/contexts/types.ts';
import { PingData, SolarSystemConnection, SolarSystemRawType } from '@/hooks/Mapper/types';
import { MapHandlers, OutCommand, OutCommandHandler } from '@/hooks/Mapper/types/mapHandlers.ts';
import { ctxManager } from '@/hooks/Mapper/utils/contextManager.ts';
import type { PanelPosition } from '@reactflow/core';
import clsx from 'clsx';
import { ForwardedRef, forwardRef, MouseEvent, useCallback, useEffect, useMemo, useRef } from 'react';
import ReactFlow, {
  Background,
  Edge,
  MiniMap,
  Node,
  NodeChange,
  NodeDragHandler,
  OnConnect,
  OnMoveEnd,
  OnSelectionChangeFunc,
  SelectionDragHandler,
  SelectionMode,
  useReactFlow,
} from 'reactflow';
import 'reactflow/dist/style.css';
import classes from './Map.module.scss';
import { MapProvider, useMapState } from './MapProvider';
import {
  ContextMenuConnection,
  ContextMenuRoot,
  SolarSystemEdge,
  useContextMenuConnectionHandlers,
  useContextMenuRootHandlers,
} from './components';
import { getBehaviorForTheme } from './helpers/getThemeBehavior';
import { useEdgesState, useMapHandlers, useNodesState, useUpdateNodes } from './hooks';
import { useBackgroundVars } from './hooks/useBackgroundVars';
import { MapViewport, OnMapAddSystemCallback, OnMapSelectionChange } from './map.types';
import type { Viewport } from '@reactflow/core/dist/esm/types';
import { usePrevious } from 'primereact/hooks';

const initialNodes: Node<SolarSystemRawType>[] = [
  // {
  //   id: '31122321',
  //   width: 100,
  //   height: 28,
  //   position: { x: 0, y: 0 },
  //   data: {
  //     id: '31122321',
  //     solarSystemName: 'J111447',
  //     classTitle: 'C6',
  //   },
  //   type: 'custom',
  // },
];

const initialEdges = [
  {
    id: '1-2',
    source: '_____kek',
    target: '_____cheburek',
    sourceHandle: 'c',
    targetHandle: 'a',
    type: 'floating',
    // markerEnd: { type: MarkerType.Arrow },
    label: 'updatable edge',
  },
];

const edgeTypes = {
  floating: SolarSystemEdge,
};

export const MAP_ROOT_ID = 'MAP_ROOT_ID';

interface MapCompProps {
  refn: ForwardedRef<MapHandlers>;
  onCommand: OutCommandHandler;
  onSelectionChange: OnMapSelectionChange;
  onConnectionInfoClick?(e: SolarSystemConnection): void;
  onAddSystem?: OnMapAddSystemCallback;
  onSelectionContextMenu?: NodeSelectionMouseHandler;
  onChangeViewport?: (viewport: MapViewport) => void;
  minimapClasses?: string;
  isShowMinimap?: boolean;
  onSystemContextMenu: (event: MouseEvent<Element>, systemId: string) => void;
  showKSpaceBG?: boolean;
  isThickConnections?: boolean;
  isShowBackgroundPattern?: boolean;
  isSoftBackground?: boolean;
  theme?: string;
  pings: PingData[];
  minimapPlacement?: PanelPosition;
  localShowShipName?: boolean;
  defaultViewport?: Viewport;
}

const MapComp = ({
  refn,
  onCommand,
  minimapClasses,
  onSelectionChange,
  onSystemContextMenu,
  onConnectionInfoClick,
  onSelectionContextMenu,
  isShowMinimap,
  showKSpaceBG,
  isThickConnections,
  isShowBackgroundPattern,
  isSoftBackground,
  theme,
  onAddSystem,
  pings,
  minimapPlacement = 'bottom-right',
  localShowShipName = false,
  onChangeViewport,
  defaultViewport,
}: MapCompProps) => {
  const { getNodes, setViewport } = useReactFlow();
  const [nodes, , onNodesChange] = useNodesState<Node<SolarSystemRawType>>(initialNodes);
  const [edges, , onEdgesChange] = useEdgesState<Edge<SolarSystemConnection>>(initialEdges);

  useMapHandlers(refn, onSelectionChange);
  useUpdateNodes(nodes);

  const { handleRootContext, ...rootCtxProps } = useContextMenuRootHandlers({ onAddSystem, onCommand });
  const { handleConnectionContext, ...connectionCtxProps } = useContextMenuConnectionHandlers();
  const { update } = useMapState();
  const { variant, gap, size, color } = useBackgroundVars(theme);
  const { isPanAndDrag, nodeComponent, connectionMode } = getBehaviorForTheme(theme || 'default');

  const refVars = useRef({ onChangeViewport });
  refVars.current = { onChangeViewport };

  const nodeTypes = useMemo(() => {
    return {
      custom: nodeComponent,
    };
  }, [nodeComponent]);

  const onConnect: OnConnect = useCallback(
    params => {
      const { source, target } = params;

      onCommand({
        type: OutCommand.manualAddConnection,
        data: { source, target },
      });
    },
    [onCommand],
  );

  const handleDragStop: NodeDragHandler = useCallback(
    (_, node) => [
      // eslint-disable-next-line no-console
      setTimeout(() => {
        onCommand({
          type: OutCommand.updateSystemPosition,
          data: { solar_system_id: node.id, position: node.position },
        });
      }, 500),
    ],
    [onCommand],
  );

  const handleSelectionDragStop: SelectionDragHandler = useCallback(
    (_, nodes) => {
      setTimeout(() => {
        onCommand({
          type: OutCommand.updateSystemPositions,
          data: nodes.map(x => ({ solar_system_id: x.id, position: x.position })),
        });
      }, 500);
    },
    [onCommand],
  );

  const resetContexts = useCallback(() => ctxManager.reset(), []);

  const handleSelectionChange: OnSelectionChangeFunc = useCallback(
    ({ edges, nodes }) => {
      onSelectionChange({
        connections: edges.map(({ source, target }) => ({ source, target })),
        systems: nodes.map(x => x.id),
      });
    },
    [onSelectionChange],
  );

  const handleMoveEnd: OnMoveEnd = useCallback((_, viewport) => {
    // @ts-ignore
    refVars.current.onChangeViewport?.(viewport);
  }, []);

  const handleNodesChange = useCallback(
    (changes: NodeChange[]) => {
      // prevents single node deselection on background / same node click
      // allows deseletion of all nodes if multiple are currently selected
      if (changes.length === 1 && changes[0].type == 'select' && changes[0].selected === false) {
        changes[0].selected = getNodes().filter(node => node.selected).length === 1;
      }

      const nextChanges = changes.reduce((acc, change) => {
        return [...acc, change];
      }, [] as NodeChange[]);

      onNodesChange(nextChanges);
    },
    [getNodes, onNodesChange],
  );

  useEffect(() => {
    update(x => ({
      ...x,
      showKSpaceBG: showKSpaceBG,
      isThickConnections: isThickConnections,
      pings,
      localShowShipName,
    }));
  }, [showKSpaceBG, isThickConnections, pings, update, localShowShipName]);

  const prevViewport = usePrevious(defaultViewport);
  useEffect(() => {
    if (defaultViewport == null) {
      return;
    }

    if (prevViewport == null) {
      return;
    }

    setViewport(defaultViewport);
  }, [defaultViewport, prevViewport, setViewport]);

  return (
    <>
      <div
        data-window-id={MAP_ROOT_ID}
        className={clsx(classes.MapRoot, { [classes.BackgroundAlternateColor]: isSoftBackground })}
      >
        <ReactFlow
          nodes={nodes}
          edges={edges}
          onNodesChange={handleNodesChange}
          onEdgesChange={onEdgesChange}
          onConnect={onConnect}
          // TODO we need save into session all of this
          //      and on any action do either
          defaultViewport={defaultViewport}
          edgeTypes={edgeTypes}
          nodeTypes={nodeTypes}
          connectionMode={connectionMode}
          snapToGrid
          nodeDragThreshold={10}
          onNodeDragStop={handleDragStop}
          onSelectionDragStop={handleSelectionDragStop}
          onConnectStart={() => update({ isConnecting: true })}
          onConnectEnd={() => update({ isConnecting: false })}
          onNodeMouseEnter={(_, node) => update({ hoverNodeId: node.id })}
          onPaneClick={event => {
            event.preventDefault();
            event.stopPropagation();
          }}
          // onKeyUp=
          onNodeMouseLeave={() => update({ hoverNodeId: null })}
          onEdgeClick={(_, t) => {
            onConnectionInfoClick?.(t.data);
          }}
          onEdgeContextMenu={handleConnectionContext}
          onNodeContextMenu={(ev, node) => onSystemContextMenu(ev, node.id)}
          // TODO don't know why this error appear - but it annoying
          // eslint-disable-next-line @typescript-eslint/ban-ts-comment
          // @ts-expect-error
          onPaneContextMenu={handleRootContext}
          onSelectionContextMenu={(ev, nodes) => onSelectionContextMenu?.(ev, nodes)}
          onSelectionChange={handleSelectionChange} // TODO - somewhy calling 2 times. don't know why
          // onSelectionEnd={handleSelectionChange}
          onMoveStart={resetContexts}
          onMouseDown={resetContexts}
          onMoveEnd={handleMoveEnd}
          minZoom={0.2}
          maxZoom={1.5}
          elevateNodesOnSelect
          deleteKeyCode={['']}
          {...(isPanAndDrag
            ? {
                selectionOnDrag: true,
                panOnDrag: [2],
              }
            : {})}
          // TODO need create clear example with problem with that flag
          //  if system is not visible edge not drawing (and any render in Custom node is not happening)
          // onlyRenderVisibleElements
          selectionMode={SelectionMode.Partial}
        >
          {isShowMinimap && (
            <MiniMap pannable zoomable ariaLabel="Mini map" className={minimapClasses} position={minimapPlacement} />
          )}
          {isShowBackgroundPattern && <Background variant={variant} gap={gap} size={size} color={color} />}
        </ReactFlow>
        {/* <button className="z-auto btn btn-primary absolute top-20 right-20" onClick={handleGetPassages}>
          Test // DON NOT REMOVE
        </button> */}
      </div>

      <ContextMenuRoot {...rootCtxProps} />
      <ContextMenuConnection {...connectionCtxProps} />
    </>
  );
};

export type MapPropsType = Omit<MapCompProps, 'refn'>;

// TODO: INFO - this component needs for correct work map provider
// eslint-disable-next-line react/display-name
export const Map = forwardRef((props: MapPropsType, ref: ForwardedRef<MapHandlers>) => {
  return (
    <MapProvider onCommand={props.onCommand}>
      <MapComp refn={ref} {...props} />
    </MapProvider>
  );
});
