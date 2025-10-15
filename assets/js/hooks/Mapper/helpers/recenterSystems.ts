import { XYPosition } from 'reactflow';

export type WithPosition<T = unknown> = T & { position: XYPosition };

export const computeBoundsCenter = (items: Array<WithPosition>): XYPosition => {
  if (items.length === 0) return { x: 0, y: 0 };

  let minX = Infinity;
  let maxX = -Infinity;
  let minY = Infinity;
  let maxY = -Infinity;

  for (const { position } of items) {
    if (position.x < minX) minX = position.x;
    if (position.x > maxX) maxX = position.x;
    if (position.y < minY) minY = position.y;
    if (position.y > maxY) maxY = position.y;
  }

  return {
    x: minX + (maxX - minX) / 2,
    y: minY + (maxY - minY) / 2,
  };
};

/** Смещает все точки так, чтобы центр области стал (0,0) */
export const recenterSystemsByBounds = <T extends WithPosition>(items: T[]): { center: XYPosition; systems: T[] } => {
  const center = computeBoundsCenter(items);

  const systems = items.map(it => ({
    ...it,
    position: {
      x: it.position.x - center.x,
      y: it.position.y - center.y,
    },
  }));

  return { center, systems };
};
