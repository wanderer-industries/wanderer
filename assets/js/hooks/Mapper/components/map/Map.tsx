import { ForwardedRef, forwardRef, MouseEvent, useCallback, useEffect } from 'react';
import ReactFlow, {
  Background,
  ConnectionMode,
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
import './styles/neon-theme.scss';
import './styles/eve-common.scss';
import { MapProvider, useMapState } from './MapProvider';
import { useEdgesState, useMapHandlers, useNodesState, useUpdateNodes } from './hooks';
import { MapHandlers, OutCommand, OutCommandHandler } from '@/hooks/Mapper/types/mapHandlers.ts';
import {
  ContextMenuConnection,
  ContextMenuRoot,
  SolarSystemEdge,
  SolarSystemNode,
  useContextMenuConnectionHandlers,
  useContextMenuRootHandlers,
} from './components';
import { OnMapAddSystemCallback, OnMapSelectionChange } from './map.types';
import { SESSION_KEY } from '@/hooks/Mapper/constants.ts';
import { SolarSystemConnection, SolarSystemRawType } from '@/hooks/Mapper/types';
import { ctxManager } from '@/hooks/Mapper/utils/contextManager.ts';
import { NodeSelectionMouseHandler } from '@/hooks/Mapper/components/contexts/types.ts';
import clsx from 'clsx';

const DEFAULT_VIEW_PORT = { zoom: 1, x: 0, y: 0 };

const getViewPortFromStore = () => {
  const restored = localStorage.getItem(SESSION_KEY.viewPort);

  if (!restored) {
    return { ...DEFAULT_VIEW_PORT };
  }

  return JSON.parse(restored);
};

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

const nodeTypes = {
  // eslint-disable-next-line @typescript-eslint/ban-ts-comment
  // @ts-ignore
  custom: SolarSystemNode,
} as never;

const edgeTypes = {
  floating: SolarSystemEdge,
};

interface MapCompProps {
  refn: ForwardedRef<MapHandlers>;
  onCommand: OutCommandHandler;
  onSelectionChange: OnMapSelectionChange;
  onManualDelete(systems: string[]): void;
  onConnectionInfoClick?(e: SolarSystemConnection): void;
  onAddSystem?: OnMapAddSystemCallback;
  onSelectionContextMenu?: NodeSelectionMouseHandler;
  minimapClasses?: string;
  isShowMinimap?: boolean;
  onSystemContextMenu: (event: MouseEvent<Element>, systemId: string) => void;
  showKSpaceBG?: boolean;
  isThickConnections?: boolean;
  isShowBackgroundPattern?: boolean;
  isSoftBackground?: boolean;
}

const MapComp = ({
  refn,
  onCommand,
  minimapClasses,
  onSelectionChange,
  onSystemContextMenu,
  onConnectionInfoClick,
  onSelectionContextMenu,
  onManualDelete,
  isShowMinimap,
  showKSpaceBG,
  isThickConnections,
  isShowBackgroundPattern,
  isSoftBackground,
  onAddSystem,
}: MapCompProps) => {
  const { getNode } = useReactFlow();
  const [nodes, , onNodesChange] = useNodesState<Node<SolarSystemRawType>>(initialNodes);
  const [edges, , onEdgesChange] = useEdgesState<Edge<SolarSystemConnection>>(initialEdges);

  useMapHandlers(refn, onSelectionChange);
  useUpdateNodes(nodes);
  const { handleRootContext, ...rootCtxProps } = useContextMenuRootHandlers({ onAddSystem });
  const { handleConnectionContext, ...connectionCtxProps } = useContextMenuConnectionHandlers();
  const { update } = useMapState();

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

  const handleMoveEnd: OnMoveEnd = (_, viewport) => {
    localStorage.setItem(SESSION_KEY.viewPort, JSON.stringify(viewport));
  };

  const handleNodesChange = useCallback(
    (changes: NodeChange[]) => {
      const systemsIdsToRemove: string[] = [];

      const nextChanges = changes.reduce((acc, change) => {
        if (change.type !== 'remove') {
          return [...acc, change];
        }

        const node = getNode(change.id);
        if (!node) {
          return [...acc, change];
        }

        if (node.data.locked) {
          return acc;
        }

        systemsIdsToRemove.push(node.data.id);
        return [...acc, change];
      }, [] as NodeChange[]);

      if (systemsIdsToRemove.length > 0) {
        onManualDelete(systemsIdsToRemove);
      }

      onNodesChange(nextChanges);
    },
    [getNode, onManualDelete, onNodesChange],
  );

  useEffect(() => {
    update(x => ({
      ...x,
      showKSpaceBG: showKSpaceBG,
      isThickConnections: isThickConnections,
    }));
  }, [showKSpaceBG, isThickConnections, update]);

  return (
    <>
      <div className={clsx(classes.MapRoot, { ['bg-neutral-900']: isSoftBackground })}>
        <ReactFlow
          nodes={nodes}
          edges={edges}
          onNodesChange={handleNodesChange}
          onEdgesChange={onEdgesChange}
          onConnect={onConnect}
          // TODO we need save into session all of this
          //      and on any action do either
          defaultViewport={getViewPortFromStore()}
          edgeTypes={edgeTypes}
          nodeTypes={nodeTypes}
          connectionMode={ConnectionMode.Loose}
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
          deleteKeyCode={['Delete']}
          // TODO need create clear example with problem with that flag
          //  if system is not visible edge not drawing (and any render in Custom node is not happening)
          // onlyRenderVisibleElements
          selectionMode={SelectionMode.Partial}
        >
          {isShowMinimap && <MiniMap pannable zoomable ariaLabel="Mini map" className={minimapClasses} />}
          {isShowBackgroundPattern && <Background />}
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
