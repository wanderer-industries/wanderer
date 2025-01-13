import { Node, useReactFlow } from 'reactflow';
import { useCallback, useRef } from 'react';
import { CommandUpdateSystems } from '@/hooks/Mapper/types/mapHandlers.ts';
import { convertSystem2Node } from '../../helpers/index.ts';
import { useMapState } from '@/hooks/Mapper/components/map/MapProvider.tsx';

export const useMapUpdateSystems = () => {
  const rf = useReactFlow();

  const {
    update,
    data: { systems },
  } = useMapState();

  const ref = useRef({ systems, update });
  ref.current = { systems, update };

  return useCallback(
    (systems: CommandUpdateSystems) => {
      const nodes = rf.getNodes();
      const prepared: Node[] = nodes.map(node => {
        const system = systems.find(s => s.id === node.id);

        if (system) {
          return {
            ...node,
            ...convertSystem2Node(system),
          };
        } else {
          return node;
        }
      });

      rf.setNodes(prepared);

      const out = ref.current.systems.map(current => {
        const newSystem = systems.find(x => current.id === x.id);
        if (!newSystem) {
          return current;
        }

        return newSystem;
      });

      update({ systems: out }, true);
    },
    [rf, update],
  );
};
