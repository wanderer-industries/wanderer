import { useCallback, useMemo, useState } from 'react';

import classes from './SolarSystemEdge.module.scss';
import { EdgeLabelRenderer, EdgeProps, getBezierPath, Position, useStore } from 'reactflow';
import { getEdgeParams } from '@/hooks/Mapper/components/map/utils.ts';
import clsx from 'clsx';
import { MassState, ShipSizeStatus, SolarSystemConnection, TimeStatus } from '@/hooks/Mapper/types';
import { PrimeIcons } from 'primereact/api';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';

const MAP_TRANSLATES: Record<string, string> = {
  [Position.Top]: 'translate(-50%, 0%)',
  [Position.Bottom]: 'translate(-50%, -100%)',
  [Position.Left]: 'translate(0%, -50%)',
  [Position.Right]: 'translate(-100%, -50%)',
};

export const SolarSystemEdge = ({ id, source, target, markerEnd, style, data }: EdgeProps<SolarSystemConnection>) => {
  const sourceNode = useStore(useCallback(store => store.nodeInternals.get(source), [source]));
  const targetNode = useStore(useCallback(store => store.nodeInternals.get(target), [target]));

  const [hovered, setHovered] = useState(false);

  const [path, labelX, labelY, sx, sy, tx, ty, sourcePos, targetPos] = useMemo(() => {
    const { sx, sy, tx, ty, sourcePos, targetPos } = getEdgeParams(sourceNode, targetNode);

    const [edgePath, labelX, labelY] = getBezierPath({
      sourceX: sx,
      sourceY: sy,
      sourcePosition: sourcePos,
      targetPosition: targetPos,
      targetX: tx,
      targetY: ty,
    });
    return [edgePath, labelX, labelY, sx, sy, tx, ty, sourcePos, targetPos];
  }, [sourceNode, targetNode]);

  if (!sourceNode || !targetNode || !data) {
    return null;
  }

  return (
    <>
      <path
        id={`back_${id}`}
        className={clsx(classes.EdgePathBack, {
          [classes.TimeCrit]: data.time_status === TimeStatus.eol,
          [classes.Hovered]: hovered,
        })}
        d={path}
        markerEnd={markerEnd}
        style={style}
      />
      <path
        id={`front_${id}`}
        className={clsx(classes.EdgePathFront, {
          [classes.Hovered]: hovered,
          [classes.MassVerge]: data.mass_status === MassState.verge,
          [classes.MassHalf]: data.mass_status === MassState.half,
          [classes.Frigate]: data.ship_size_type === ShipSizeStatus.small,
        })}
        d={path}
        markerEnd={markerEnd}
        style={style}
      />
      <path
        id={id}
        className={classes.ClickPath}
        d={path}
        markerEnd={markerEnd}
        style={style}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
      />

      <EdgeLabelRenderer>
        <div
          className={clsx(classes.Handle, 'react-flow__handle absolute nodrag pointer-events-none')}
          style={{ transform: `${MAP_TRANSLATES[sourcePos]} translate(${sx}px,${sy}px)` }}
        />
        <div
          className={clsx(classes.Handle, 'react-flow__handle absolute nodrag pointer-events-none')}
          style={{ transform: `${MAP_TRANSLATES[targetPos]} translate(${tx}px,${ty}px)` }}
        />

        <div
          className="absolute flex items-center gap-1"
          style={{
            transform: `translate(-50%, -50%) translate(${labelX}px,${labelY}px)`,
          }}
        >
          {data.locked && (
            <WdTooltipWrapper
              content="Save mass"
              className={clsx(
                classes.LinkLabel,
                'pointer-events-auto bg-amber-300 rounded opacity-100 cursor-auto text-neutral-900',
              )}
            >
              <span className={clsx(PrimeIcons.LOCK, classes.icon)} />
            </WdTooltipWrapper>
          )}
        </div>
      </EdgeLabelRenderer>
    </>
  );
};
