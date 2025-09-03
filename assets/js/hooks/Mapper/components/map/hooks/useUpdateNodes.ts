import { useMapState } from '@/hooks/Mapper/components/map/MapProvider.tsx';
import { SolarSystemRawType } from '@/hooks/Mapper/types';
import { useCallback, useEffect, useRef } from 'react';
import { Node, useOnViewportChange, useReactFlow } from 'reactflow';

const useThrottle = () => {
  const throttleSeed = useRef<number | null>(null);

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const throttleFunction = useRef((func: any, delay = 200) => {
    if (!throttleSeed.current) {
      func();
      throttleSeed.current = setTimeout(() => {
        throttleSeed.current = null;
      }, delay);
    }
  });

  return throttleFunction.current;
};

const X_OFFSET = 50;
const Y_OFFSET = 50;

const isNodeVisible = (node: Node, viewport: { x: number; y: number; width: number; height: number }) => {
  const { x: nodeX, y: nodeY } = node.position;
  const { width, height } = node;

  return (
    nodeX + (width ?? 0) + X_OFFSET > viewport.x &&
    nodeX - X_OFFSET < viewport.x + viewport.width &&
    nodeY + (height ?? 0) + Y_OFFSET > viewport.y &&
    nodeY - Y_OFFSET < viewport.y + viewport.height
  );
};

export const useUpdateNodes = (nodes: Node<SolarSystemRawType>[]) => {
  const { screenToFlowPosition } = useReactFlow();
  const throttle = useThrottle();
  const { update } = useMapState();

  const ref = useRef({ screenToFlowPosition });
  ref.current = { screenToFlowPosition };

  const getViewport = useCallback(() => {
    const clientRect = document.querySelector('.react-flow__renderer')?.getBoundingClientRect();

    if (!clientRect) {
      return;
    }

    const { screenToFlowPosition } = ref.current;

    const topLeft = screenToFlowPosition({ x: clientRect.left, y: clientRect.top });
    const bottomRight = screenToFlowPosition({ x: clientRect.right, y: clientRect.bottom });
    return {
      x: topLeft.x,
      y: topLeft.y,
      width: bottomRight.x - topLeft.x,
      height: bottomRight.y - topLeft.y,
    };
  }, []);

  const updateNodesVisibility = useCallback(() => {
    if (!nodes) {
      return;
    }

    const viewport = getViewport();
    if (!viewport) {
      const visibleNodes = new Set(nodes.map(x => x.id));
      update({ visibleNodes });
      return;
    }

    const visibleNodes = new Set(nodes.filter(x => isNodeVisible(x, viewport)).map(x => x.id));
    update({ visibleNodes });
  }, [getViewport, nodes, update]);

  useOnViewportChange({
    onChange: () => throttle(updateNodesVisibility.bind(this)),
    onEnd: () => throttle(updateNodesVisibility.bind(this)),
  });

  useEffect(() => {
    updateNodesVisibility();
  }, [nodes, updateNodesVisibility]);
};
