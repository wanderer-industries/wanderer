import { Node, useReactFlow } from 'reactflow';
import { useCallback } from 'react';
import { CommandAddSystems } from '@/hooks/Mapper/types/mapHandlers.ts';
import { convertSystem2Node } from '../../helpers';

export const useMapAddSystems = () => {
  const rf = useReactFlow();

  return useCallback(
    (systems: CommandAddSystems) => {
      const nodes = rf.getNodes();
      const prepared: Node[] = systems.filter(x => !nodes.some(y => x.id === y.id)).map(convertSystem2Node);
      rf.addNodes(prepared);
    },
    [rf],
  );
};
