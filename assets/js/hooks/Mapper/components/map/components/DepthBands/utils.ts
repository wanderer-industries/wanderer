import { isHorizontalLayoutDirection, ManagedLayoutDirection } from '../../map.types.ts';
import type { DepthBand, DepthBandsDirection } from './depthBands.ts';

const VERTICAL_LAYOUT_LABEL_REPEAT_DISTANCE = 320;
const HORIZONTAL_LAYOUT_LABEL_REPEAT_DISTANCE = 240;
const LABEL_EDGE_OFFSET = 12;

export interface RepeatedLabelPosition {
  x: number;
  y: number;
}

export function buildRepeatedLabelPositions(band: DepthBand, direction: DepthBandsDirection): RepeatedLabelPosition[] {
  const horizontalLayout = isHorizontalLayoutDirection(direction);
  const start = horizontalLayout ? band.top : band.left;
  const length = horizontalLayout ? band.height : band.width;
  const count = getLabelRepeatCount(length, horizontalLayout);
  const segmentLength = length / count;

  return Array.from({ length: count }, (_, index) => {
    const axisPosition = start + segmentLength * (index + 0.5);

    if (horizontalLayout) {
      return { x: band.left + LABEL_EDGE_OFFSET, y: axisPosition };
    }

    return { x: axisPosition, y: getVerticalLabelY(band, direction) };
  });
}

export function getLabelRepeatCount(length: number, horizontalLayout: boolean): number {
  const repeatDistance = getLabelRepeatDistance(horizontalLayout);
  return Math.max(1, Math.floor(length / repeatDistance));
}

function getLabelRepeatDistance(horizontalLayout: boolean): number {
  if (horizontalLayout) return HORIZONTAL_LAYOUT_LABEL_REPEAT_DISTANCE;
  return VERTICAL_LAYOUT_LABEL_REPEAT_DISTANCE;
}

function getVerticalLabelY(band: DepthBand, direction: DepthBandsDirection): number {
  if (direction === ManagedLayoutDirection.BottomTop) return band.top + LABEL_EDGE_OFFSET;
  return band.top + band.height - LABEL_EDGE_OFFSET;
}
