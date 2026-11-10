import { CSSProperties, MouseEvent, useEffect, useMemo, useState } from 'react';
import clsx from 'clsx';
import { Node, useViewport } from 'reactflow';
import { useMapCheckPermissions } from '@/hooks/Mapper/mapRootProvider/hooks/api';
import { OutCommand, OutCommandHandler } from '@/hooks/Mapper/types/mapHandlers.ts';
import { UserPermission } from '@/hooks/Mapper/types/permissions.ts';
import { SolarSystemRawType } from '@/hooks/Mapper/types';
import { isHorizontalLayoutDirection, ManagedLayoutDirection } from '../../map.types.ts';

const NODE_WIDTH = 130;
const NODE_HEIGHT = 34;
const TOP_BOTTOM_CONTROL_OFFSET = 30;
const LEFT_RIGHT_CONTROL_OFFSET = 52;
const MOVE_TIMEOUT_MS = 10_000;
const LOCK_SYSTEM_PERMISSIONS = [UserPermission.LOCK_SYSTEM];
const CONTROL_BUTTON_CLASS =
  'pointer-events-auto flex h-6 w-7 items-center justify-center border-0 bg-transparent p-0 text-white/70 drop-shadow-[0_0_5px_rgba(255,255,255,0.35)] transition duration-150 hover:scale-110 hover:text-white disabled:cursor-default disabled:opacity-20 disabled:drop-shadow-none disabled:hover:scale-100';

export interface ArrowPathVariant {
  className: string;
  d: string;
  fill: 'none' | 'currentColor';
  stroke: 'none' | 'currentColor';
  strokeWidth: number;
}

export interface ArrowVariant {
  id: string;
  paths: readonly ArrowPathVariant[];
}

const ARROW_VARIANT: ArrowVariant = {
  id: 'amber-hybrid',
  paths: [
    {
      className: 'text-amber-300/85',
      d: 'M21 3h-4l-9 9 9 9h4l-9-9z',
      fill: 'currentColor',
      stroke: 'none',
      strokeWidth: 0,
    },
    { className: 'text-orange-200/90', d: 'M12 4l-8 8 8 8', fill: 'none', stroke: 'currentColor', strokeWidth: 2.35 },
  ],
};

export interface LockedRootControlsProps {
  nodes: Node<SolarSystemRawType>[];
  direction: ManagedLayoutDirection;
  onCommand: OutCommandHandler;
}

interface ControlPlacement {
  left: number;
  top: number;
  vertical: boolean;
  stackClassName: string;
}

function getControlPlacement(node: Node<SolarSystemRawType>, direction: ManagedLayoutDirection): ControlPlacement {
  const width = node.width ?? NODE_WIDTH;
  const height = node.height ?? NODE_HEIGHT;

  if (direction === ManagedLayoutDirection.TopBottom) {
    return {
      left: node.position.x + width / 2,
      top: node.position.y - TOP_BOTTOM_CONTROL_OFFSET,
      vertical: false,
      stackClassName: '-translate-x-1/2 -translate-y-full',
    };
  }

  if (direction === ManagedLayoutDirection.BottomTop) {
    return {
      left: node.position.x + width / 2,
      top: node.position.y + height + TOP_BOTTOM_CONTROL_OFFSET,
      vertical: false,
      stackClassName: '-translate-x-1/2',
    };
  }

  if (direction === ManagedLayoutDirection.RightLeft) {
    return {
      left: node.position.x + width + LEFT_RIGHT_CONTROL_OFFSET,
      top: node.position.y + height / 2,
      vertical: true,
      stackClassName: '-translate-x-1/2 -translate-y-1/2',
    };
  }

  return {
    left: node.position.x - LEFT_RIGHT_CONTROL_OFFSET,
    top: node.position.y + height / 2,
    vertical: true,
    stackClassName: '-translate-x-1/2 -translate-y-1/2',
  };
}

function visualOrder(node: Node<SolarSystemRawType>, direction: ManagedLayoutDirection): number {
  if (isHorizontalLayoutDirection(direction)) return node.position.y;
  return node.position.x;
}

function sortLockedNodes(nodes: Node<SolarSystemRawType>[], direction: ManagedLayoutDirection) {
  return nodes
    .filter(node => node.data.locked)
    .sort((left, right) => {
      const leftIndex = left.data.sort_index;
      const rightIndex = right.data.sort_index;

      if (leftIndex != null && rightIndex != null) return leftIndex - rightIndex;
      if (leftIndex != null) return -1;
      if (rightIndex != null) return 1;
      return visualOrder(left, direction) - visualOrder(right, direction);
    });
}

function getChevronRotation(vertical: boolean, forward: boolean): string {
  if (vertical && forward) return '-rotate-90';
  if (vertical) return 'rotate-90';
  if (forward) return 'rotate-180';
  return '';
}

function buildLockedPositionKey(nodes: Node<SolarSystemRawType>[]): string {
  return nodes
    .filter(node => node.data.locked)
    .sort((left, right) => left.id.localeCompare(right.id))
    .map(node => `${node.id}:${node.position.x}:${node.position.y}`)
    .join('|');
}

export interface ArrowGlyphProps {
  rotation: string;
  variant: ArrowVariant;
}

export const ArrowGlyph = ({ rotation, variant }: ArrowGlyphProps) => (
  <svg viewBox="0 0 24 24" className={clsx('h-6 w-6 overflow-visible', rotation)} aria-hidden="true">
    {variant.paths.map(path => (
      <path
        key={path.d}
        className={path.className}
        d={path.d}
        fill={path.fill}
        stroke={path.stroke}
        strokeWidth={path.strokeWidth}
        strokeLinecap="square"
        strokeLinejoin="miter"
      />
    ))}
  </svg>
);

export const LockedRootControls = ({ nodes, direction, onCommand }: LockedRootControlsProps) => {
  const viewport = useViewport();
  const canLockSystem = useMapCheckPermissions(LOCK_SYSTEM_PERMISSIONS);
  const lockedNodes = useMemo(() => sortLockedNodes(nodes, direction), [direction, nodes]);
  const lockedPositionKey = useMemo(() => buildLockedPositionKey(nodes), [nodes]);
  const [pendingPositionKey, setPendingPositionKey] = useState<string | null>(null);
  const movePending = pendingPositionKey != null;
  const viewportStyle: CSSProperties = {
    transform: `translate(${viewport.x}px, ${viewport.y}px) scale(${viewport.zoom})`,
    transformOrigin: '0 0',
  };

  useEffect(() => {
    if (pendingPositionKey == null || pendingPositionKey === lockedPositionKey) return;
    setPendingPositionKey(null);
  }, [lockedPositionKey, pendingPositionKey]);

  useEffect(() => {
    if (pendingPositionKey == null) return;

    const timeout = window.setTimeout(() => setPendingPositionKey(null), MOVE_TIMEOUT_MS);
    return () => window.clearTimeout(timeout);
  }, [pendingPositionKey]);

  if (!canLockSystem || lockedNodes.length === 0) return null;

  const move = (event: MouseEvent<HTMLButtonElement>, systemId: string, offset: -1 | 1) => {
    event.preventDefault();
    event.stopPropagation();
    setPendingPositionKey(lockedPositionKey);
    void onCommand({ type: OutCommand.moveLockedSystem, data: { system_id: systemId, offset } }).catch(() => {
      setPendingPositionKey(null);
    });
  };

  return (
    <div className="pointer-events-none absolute inset-0 z-[6] overflow-hidden">
      <div className="absolute left-0 top-0" style={viewportStyle}>
        {lockedNodes.map((node, index) => {
          const placement = getControlPlacement(node, direction);
          const backwardRotation = getChevronRotation(placement.vertical, false);
          const forwardRotation = getChevronRotation(placement.vertical, true);

          return (
            <div
              key={node.id}
              className={clsx('absolute flex flex-col gap-0.5', placement.stackClassName)}
              style={{ left: placement.left, top: placement.top }}
            >
              <div
                className={clsx('flex', {
                  'flex-col gap-0.5': placement.vertical,
                  'gap-2': !placement.vertical,
                })}
              >
                <button
                  type="button"
                  className={CONTROL_BUTTON_CLASS}
                  disabled={movePending || index === 0}
                  aria-label="Move locked chain backward"
                  onClick={event => move(event, node.id, -1)}
                  onPointerDown={event => event.stopPropagation()}
                >
                  <ArrowGlyph variant={ARROW_VARIANT} rotation={backwardRotation} />
                </button>
                <button
                  type="button"
                  className={CONTROL_BUTTON_CLASS}
                  disabled={movePending || index === lockedNodes.length - 1}
                  aria-label="Move locked chain forward"
                  onClick={event => move(event, node.id, 1)}
                  onPointerDown={event => event.stopPropagation()}
                >
                  <ArrowGlyph variant={ARROW_VARIANT} rotation={forwardRotation} />
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};
