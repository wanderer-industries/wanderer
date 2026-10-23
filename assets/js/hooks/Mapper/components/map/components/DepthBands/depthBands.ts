import { Edge, Node } from 'reactflow';
import { isHorizontalLayoutDirection, ManagedLayoutDirection } from '../../map.types.ts';

export type DepthBandsDirection = ManagedLayoutDirection;

export interface DepthBand {
  depth: number;
  left: number;
  top: number;
  width: number;
  height: number;
  labelX: number;
  labelY: number;
  backgroundColor: string;
  borderColor: string;
}

interface DepthLane {
  center: number;
  nodes: Node[];
}

const DEFAULT_NODE_WIDTH = 130;
const DEFAULT_NODE_HEIGHT = 34;
const LANE_TOLERANCE = 24;
const OUTER_PADDING = 24;
const LABEL_GUTTER = 44;
const LABEL_OFFSET = 30;
const BAND_GAP = 8;
const START_HUE = 125;
const END_HUE = 0;

export function buildDepthBands(nodes: Node[], direction: DepthBandsDirection): DepthBand[] {
  if (nodes.length === 0) return [];
  if (isHorizontalLayoutDirection(direction)) {
    return buildColumnBands(nodes, direction);
  }
  return buildRowBands(nodes, direction);
}

export function inferDepthBandsDirection(nodes: Node[], edges: Edge[]): DepthBandsDirection | undefined {
  const nodesById = new Map(nodes.map(node => [node.id, node]));
  let horizontalDistance = 0;
  let verticalDistance = 0;
  let connectedEdges = 0;

  for (const edge of edges) {
    const source = nodesById.get(edge.source);
    const target = nodesById.get(edge.target);
    if (!source || !target) continue;

    horizontalDistance += Math.abs(nodeCenterX(source) - nodeCenterX(target));
    verticalDistance += Math.abs(nodeCenterY(source) - nodeCenterY(target));
    connectedEdges += 1;
  }

  if (connectedEdges > 0) return getPrimaryDirection(horizontalDistance, verticalDistance);
  if (nodes.length < 2) return undefined;

  const horizontalSpan = Math.max(...nodes.map(nodeCenterX)) - Math.min(...nodes.map(nodeCenterX));
  const verticalSpan = Math.max(...nodes.map(nodeCenterY)) - Math.min(...nodes.map(nodeCenterY));
  return getPrimaryDirection(horizontalSpan, verticalSpan);
}

function getPrimaryDirection(horizontalDistance: number, verticalDistance: number): DepthBandsDirection {
  if (horizontalDistance >= verticalDistance) return ManagedLayoutDirection.LeftRight;
  return ManagedLayoutDirection.TopBottom;
}

function buildColumnBands(
  nodes: Node[],
  direction: ManagedLayoutDirection.LeftRight | ManagedLayoutDirection.RightLeft,
): DepthBand[] {
  const lanes = buildLanes(nodes, nodeCenterX);
  const graphTop = Math.min(...nodes.map(node => node.position.y));
  const graphBottom = Math.max(...nodes.map(node => node.position.y + nodeHeight(node)));
  const top = graphTop - LABEL_GUTTER;
  const height = graphBottom - top + OUTER_PADDING;

  return lanes.map((lane, index) => {
    const depth = direction === ManagedLayoutDirection.LeftRight ? index : lanes.length - index - 1;
    const left = laneStart(lanes, index, DEFAULT_NODE_WIDTH);
    const right = laneEnd(lanes, index, DEFAULT_NODE_WIDTH);

    return createBand(depth, lanes.length, {
      left: left + BAND_GAP / 2,
      top,
      width: right - left - BAND_GAP,
      height,
      labelX: lane.center,
      labelY: graphTop - LABEL_OFFSET,
    });
  });
}

function buildRowBands(
  nodes: Node[],
  direction: ManagedLayoutDirection.TopBottom | ManagedLayoutDirection.BottomTop,
): DepthBand[] {
  const lanes = buildLanes(nodes, nodeCenterY);
  const graphLeft = Math.min(...nodes.map(node => node.position.x));
  const graphRight = Math.max(...nodes.map(node => node.position.x + nodeWidth(node)));
  const left = graphLeft - LABEL_GUTTER;
  const width = graphRight - left + OUTER_PADDING;

  return lanes.map((lane, index) => {
    const depth = direction === ManagedLayoutDirection.TopBottom ? index : lanes.length - index - 1;
    const top = laneStart(lanes, index, DEFAULT_NODE_HEIGHT);
    const bottom = laneEnd(lanes, index, DEFAULT_NODE_HEIGHT);

    return createBand(depth, lanes.length, {
      left,
      top: top + BAND_GAP / 2,
      width,
      height: bottom - top - BAND_GAP,
      labelX: graphLeft - LABEL_OFFSET,
      labelY: lane.center,
    });
  });
}

function createBand(
  depth: number,
  laneCount: number,
  geometry: Omit<DepthBand, 'depth' | 'backgroundColor' | 'borderColor'>,
): DepthBand {
  const progress = laneCount === 1 ? 0 : depth / (laneCount - 1);
  const hue = Math.round(START_HUE + (END_HUE - START_HUE) * progress);

  return {
    depth,
    ...geometry,
    backgroundColor: `hsla(${hue}, 42%, 34%, 0.05)`,
    borderColor: `hsla(${hue}, 55%, 52%, 0.28)`,
  };
}

function buildLanes(nodes: Node[], getCenter: (node: Node) => number): DepthLane[] {
  const sorted = [...nodes].sort(
    (left, right) => getCenter(left) - getCenter(right) || left.id.localeCompare(right.id),
  );
  const lanes: DepthLane[] = [];

  for (const node of sorted) {
    const center = getCenter(node);
    const current = lanes[lanes.length - 1];

    if (current && Math.abs(current.center - center) <= LANE_TOLERANCE) {
      current.nodes.push(node);
      current.center = current.nodes.reduce((sum, item) => sum + getCenter(item), 0) / current.nodes.length;
      continue;
    }

    lanes.push({ center, nodes: [node] });
  }

  return lanes;
}

function laneStart(lanes: DepthLane[], index: number, defaultSize: number): number {
  if (index > 0) return (lanes[index - 1].center + lanes[index].center) / 2;
  if (lanes.length > 1) return lanes[0].center - (lanes[1].center - lanes[0].center) / 2;
  return lanes[0].center - defaultSize / 2 - OUTER_PADDING;
}

function laneEnd(lanes: DepthLane[], index: number, defaultSize: number): number {
  if (index < lanes.length - 1) return (lanes[index].center + lanes[index + 1].center) / 2;
  if (lanes.length === 1) return lanes[0].center + defaultSize / 2 + OUTER_PADDING;

  const last = lanes.length - 1;
  return lanes[last].center + (lanes[last].center - lanes[last - 1].center) / 2;
}

function nodeCenterX(node: Node): number {
  return node.position.x + nodeWidth(node) / 2;
}

function nodeCenterY(node: Node): number {
  return node.position.y + nodeHeight(node) / 2;
}

function nodeWidth(node: Node): number {
  return node.width ?? DEFAULT_NODE_WIDTH;
}

function nodeHeight(node: Node): number {
  return node.height ?? DEFAULT_NODE_HEIGHT;
}
