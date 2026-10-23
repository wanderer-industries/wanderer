import { SolarSystemRawType } from '@/hooks/Mapper/types';
import { useMemo } from 'react';
import { Node } from 'reactflow';

export const useManagedLayoutNodes = (
  nodes: Node<SolarSystemRawType>[],
  managedLayoutEnabled: boolean,
): Node<SolarSystemRawType>[] => {
  return useMemo(() => {
    if (!managedLayoutEnabled) return nodes;

    return nodes.map(node => {
      if (node.draggable === false) return node;
      return { ...node, draggable: false };
    });
  }, [managedLayoutEnabled, nodes]);
};
