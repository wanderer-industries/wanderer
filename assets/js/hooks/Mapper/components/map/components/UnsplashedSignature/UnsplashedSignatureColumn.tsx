import { useCallback, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { InfoDrawer } from '@/hooks/Mapper/components/ui-kit';
import { renderInfoColumn } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/renders';
import { parseSignatureCustomInfo } from '@/hooks/Mapper/helpers/parseSignatureCustomInfo';
import { resolveSignatureFillVar } from '@/hooks/Mapper/components/map/helpers/wormholeClassFillVars';
import { MassState, TimeStatus } from '@/hooks/Mapper/types';
import { SystemSignature } from '@/hooks/Mapper/types/signatures';
import { WormholeDataRaw } from '@/hooks/Mapper/types/wormholes';

interface PillData {
  signature: SystemSignature;
  fill: string;
  isEOL: boolean;
  is4H: boolean;
  isVerge: boolean;
  isHalf: boolean;
}

const PILL_W = 13;
const PILL_H = 8;
const GAP = 2;
const COLS = 4;

interface UnsplashedSignatureColumnProps {
  signatures: SystemSignature[];
  wormholesData: Record<string, WormholeDataRaw>;
}

export const UnsplashedSignatureColumn = ({ signatures, wormholesData }: UnsplashedSignatureColumnProps) => {
  const svgRef = useRef<SVGSVGElement>(null);
  const [hoveredIndex, setHoveredIndex] = useState(-1);

  const pills: PillData[] = useMemo(() => {
    return signatures.map(sig => {
      const customInfo = parseSignatureCustomInfo(sig.custom_info);
      return {
        signature: sig,
        fill: resolveSignatureFillVar(sig, wormholesData),
        isEOL: customInfo.time_status === TimeStatus._1h,
        is4H: customInfo.time_status === TimeStatus._4h,
        isVerge: customInfo.mass_status === MassState.verge,
        isHalf: customInfo.mass_status === MassState.half,
      };
    });
  }, [signatures, wormholesData]);

  const count = pills.length;
  if (count === 0) return null;

  const cols = Math.min(count, COLS);
  const rows = Math.ceil(count / COLS);
  const svgWidth = cols * (PILL_W + GAP) - GAP;
  const svgHeight = rows * (PILL_H + GAP) - GAP;

  const onMouseMove = useCallback(
    (e: React.MouseEvent<SVGSVGElement>) => {
      const svg = svgRef.current;
      if (!svg) return;
      const rect = svg.getBoundingClientRect();
      const localX = e.clientX - rect.left;
      const localY = e.clientY - rect.top;

      const col = Math.floor(localX / (PILL_W + GAP));
      const row = Math.floor(localY / (PILL_H + GAP));

      const withinPill =
        localX - col * (PILL_W + GAP) <= PILL_W && localY - row * (PILL_H + GAP) <= PILL_H;

      const idx = withinPill ? row * COLS + col : -1;
      setHoveredIndex(idx < count ? idx : -1);
    },
    [count],
  );

  const onMouseLeave = useCallback(() => setHoveredIndex(-1), []);

  // Compute tooltip position relative to viewport
  let tooltipX = 0;
  let tooltipY = 0;
  if (hoveredIndex >= 0 && svgRef.current) {
    const svgRect = svgRef.current.getBoundingClientRect();
    const col = hoveredIndex % COLS;
    const row = Math.floor(hoveredIndex / COLS);
    tooltipX = svgRect.left + col * (PILL_W + GAP) + PILL_W / 2;
    tooltipY = svgRect.top + row * (PILL_H + GAP) - 4;
  }

  return (
    <>
      <svg
        ref={svgRef}
        width={svgWidth}
        height={svgHeight}
        viewBox={`0 0 ${svgWidth} ${svgHeight}`}
        xmlns="http://www.w3.org/2000/svg"
        style={{ display: 'block', position: 'relative', top: 3 }}
        onMouseMove={onMouseMove}
        onMouseLeave={onMouseLeave}
      >
        {pills.map((pill, i) => {
          const col = i % COLS;
          const row = Math.floor(i / COLS);
          const x = col * (PILL_W + GAP);
          const y = row * (PILL_H + GAP);
          return (
            <g key={pill.signature.eve_id} transform={`translate(${x},${y})`}>
              <rect y="1" width="13" height="4" rx="2" fill={pill.fill} />
              {pill.isEOL && <rect x="4" width="5" height="6" rx="1" fill="#a153ac" />}
              {pill.is4H && <rect x="4" width="5" height="6" rx="1" fill="#d8b4fe" />}
              {pill.isVerge && <rect x="0" width="5" height="6" rx="1" fill="#af0000" />}
              {pill.isHalf && <rect x="0" width="5" height="6" rx="1" fill="#ffd700" />}
            </g>
          );
        })}
      </svg>

      {hoveredIndex >= 0 &&
        pills[hoveredIndex] &&
        createPortal(
          <div
            style={{
              position: 'fixed',
              left: tooltipX,
              top: tooltipY,
              transform: 'translate(-50%, -100%)',
              zIndex: 9999,
              pointerEvents: 'none',
            }}
          >
            <div
              style={{
                background: 'var(--surface-card, #1e1e2e)',
                border: '1px solid var(--surface-border, #333)',
                borderRadius: 6,
                padding: '4px 6px',
                boxShadow: '0 2px 8px rgba(0,0,0,0.4)',
              }}
            >
              <div className="flex flex-col gap-1">
                <InfoDrawer title={<b className="text-slate-50">{pills[hoveredIndex].signature.eve_id}</b>}>
                  {renderInfoColumn(pills[hoveredIndex].signature)}
                </InfoDrawer>
              </div>
            </div>
          </div>,
          document.body,
        )}
    </>
  );
};
