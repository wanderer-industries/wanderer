import { Position, internalsSymbol, Node } from 'reactflow';

type Coords = [number, number];
type CoordsWithPosition = [number, number, Position];

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
