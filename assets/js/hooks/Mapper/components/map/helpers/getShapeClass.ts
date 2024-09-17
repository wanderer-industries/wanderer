import { isKnownSpace } from './isKnownSpace.ts';
import { isWormholeSpace } from './isWormholeSpace.ts';
import { isPochvenSpace } from './isPochvenSpace.ts';
import { isTriglavianInvasion } from './isTriglavianInvasion.ts';

export const getShapeClass = (systemClass: number, triglavianInvasionStatus: string) => {
  if (isPochvenSpace(systemClass) || (isKnownSpace(systemClass) && isTriglavianInvasion(triglavianInvasionStatus))) {
    return 'wd-route-system-shape-triangle';
  }

  if (isWormholeSpace(systemClass)) {
    return 'wd-route-system-shape-circle';
  }

  return '';
};
