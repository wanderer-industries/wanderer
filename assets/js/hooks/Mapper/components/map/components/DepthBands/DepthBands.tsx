import { CSSProperties, useMemo } from 'react';
import clsx from 'clsx';
import { Node, useViewport } from 'reactflow';
import { isHorizontalLayoutDirection } from '../../map.types.ts';
import { buildDepthBands, DepthBandsDirection } from './depthBands.ts';
import { buildRepeatedLabelPositions } from './utils.ts';

const GRID_BACKGROUND =
  'linear-gradient(rgba(255,255,255,0.025) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.025) 1px, transparent 1px)';
export interface DepthBandsProps {
  nodes: Node[];
  direction: DepthBandsDirection;
}

export const DepthBands = ({ nodes, direction }: DepthBandsProps) => {
  const viewport = useViewport();
  const bands = useMemo(() => buildDepthBands(nodes, direction), [direction, nodes]);
  const horizontalLayout = isHorizontalLayoutDirection(direction);
  const viewportStyle: CSSProperties = {
    transform: `translate(${viewport.x}px, ${viewport.y}px) scale(${viewport.zoom})`,
    transformOrigin: '0 0',
  };

  return (
    <div className="pointer-events-none absolute inset-0 z-[3] overflow-hidden" aria-hidden="true">
      <div className="absolute left-0 top-0" style={viewportStyle}>
        {bands.map(band => (
          <div key={band.depth}>
            <div
              className="absolute border"
              style={{
                left: band.left,
                top: band.top,
                width: band.width,
                height: band.height,
                backgroundColor: band.backgroundColor,
                borderColor: band.borderColor,
                backgroundImage: GRID_BACKGROUND,
                backgroundSize: '16px 16px',
              }}
            />
            {buildRepeatedLabelPositions(band, direction).map((position, index) => (
              <div
                key={`${band.depth}-${index}`}
                className={clsx(
                  'absolute -translate-x-1/2 -translate-y-1/2 whitespace-nowrap font-mono text-[15px] font-semibold tracking-[0.28em] text-white/40 [text-shadow:0_2px_5px_rgba(0,0,0,0.95),0_0_8px_rgba(125,211,252,0.28)]',
                  horizontalLayout && 'rotate-90',
                )}
                style={{ left: position.x, top: position.y }}
              >
                LEVEL {band.depth}
              </div>
            ))}
          </div>
        ))}
      </div>
    </div>
  );
};
