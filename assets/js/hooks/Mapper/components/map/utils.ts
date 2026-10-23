import { Position, internalsSymbol, Node } from 'reactflow';
import { isHorizontalLayoutDirection, ManagedLayoutDirection } from './map.types.ts';

type Coords = [number, number];
type CoordsWithPosition = [number, number, Position];

const DEFAULT_NODE_WIDTH = 130;
const DEFAULT_NODE_HEIGHT = 34;

function segmentsIntersect(a1: number, a2: number, b1: number, b2: number): boolean {
  const [minA, maxA] = a1 < a2 ? [a1, a2] : [a2, a1];
  const [minB, maxB] = b1 < b2 ? [b1, b2] : [b2, b1];

  return maxA >= minB && maxB >= minA;
}

function getParams(nodeA: Node, nodeB: Node): CoordsWithPosition {
  const centerA = getNodeCenter(nodeA);
  const centerB = getNodeCenter(nodeB);

  let position: Position;

  if (
    segmentsIntersect(
      nodeA.positionAbsolute!.x - 10,
      nodeA.positionAbsolute!.x - 10 + nodeA.width! + 20,
      nodeB.positionAbsolute!.x,
      nodeB.positionAbsolute!.x + nodeB.width!,
    )
  ) {
    position = centerA.y > centerB.y ? Position.Top : Position.Bottom;
  } else {
    position = centerA.x > centerB.x ? Position.Left : Position.Right;
  }

  const [x, y] = getHandleCoordsByPosition(nodeA, position);
  return [x, y, position];
}

function getHandleCoordsByPosition(node: Node, handlePosition: Position): Coords {
  const handle = node[internalsSymbol]!.handleBounds!.source!.find(h => h.position === handlePosition);

  if (!handle) {
    throw new Error(`Handle with position ${handlePosition} not found on node ${node.id}`);
  }

  let offsetX = handle.width / 2;
  let offsetY = handle.height / 2;

  switch (handlePosition) {
    case Position.Left:
      offsetX = 0;
      break;
    case Position.Right:
      offsetX = handle.width;
      break;
    case Position.Top:
      offsetY = 0;
      break;
    case Position.Bottom:
      offsetY = handle.height;
      break;
  }

  const x = node.positionAbsolute!.x + handle.x + offsetX;
  const y = node.positionAbsolute!.y + handle.y + offsetY;

  return [x, y];
}

function getNodeCenter(node: Node): { x: number; y: number } {
  return {
    x: node.positionAbsolute!.x + node.width! / 2,
    y: node.positionAbsolute!.y + node.height! / 2,
  };
}

export function getEdgeParams(source: Node, target: Node) {
  const [sx, sy, sourcePos] = getParams(source, target);
  const [tx, ty, targetPos] = getParams(target, source);

  return {
    sx,
    sy,
    tx,
    ty,
    sourcePos,
    targetPos,
  };
}

export function getManagedEdgeParams(source: Node, target: Node, direction: ManagedLayoutDirection) {
  const [sourcePos, targetPos] = getManagedHandlePositions(source, target, direction);
  const [sx, sy] = getHandleCoordsByPosition(source, sourcePos);
  const [tx, ty] = getHandleCoordsByPosition(target, targetPos);

  return { sx, sy, tx, ty, sourcePos, targetPos };
}

export function getManagedHandlePositions(
  source: Node,
  target: Node,
  direction: ManagedLayoutDirection,
): [Position, Position] {
  const sourceCenter = getNodeCenter(source);
  const targetCenter = getNodeCenter(target);
  const verticalLayout = !isHorizontalLayoutDirection(direction);

  if (verticalLayout) {
    const sourceHeight = source.height ?? DEFAULT_NODE_HEIGHT;
    const targetHeight = target.height ?? DEFAULT_NODE_HEIGHT;
    const sameLevel = Math.abs(sourceCenter.y - targetCenter.y) < Math.max(sourceHeight, targetHeight);
    if (sameLevel) return horizontalHandlePositions(sourceCenter.x, targetCenter.x);
    return verticalHandlePositions(sourceCenter.y, targetCenter.y);
  }

  const sourceWidth = source.width ?? DEFAULT_NODE_WIDTH;
  const targetWidth = target.width ?? DEFAULT_NODE_WIDTH;
  const sameLevel = Math.abs(sourceCenter.x - targetCenter.x) < Math.max(sourceWidth, targetWidth);
  if (sameLevel) return verticalHandlePositions(sourceCenter.y, targetCenter.y);
  return horizontalHandlePositions(sourceCenter.x, targetCenter.x);
}

function horizontalHandlePositions(sourceX: number, targetX: number): [Position, Position] {
  if (sourceX <= targetX) return [Position.Right, Position.Left];
  return [Position.Left, Position.Right];
}

function verticalHandlePositions(sourceY: number, targetY: number): [Position, Position] {
  if (sourceY <= targetY) return [Position.Bottom, Position.Top];
  return [Position.Top, Position.Bottom];
}
