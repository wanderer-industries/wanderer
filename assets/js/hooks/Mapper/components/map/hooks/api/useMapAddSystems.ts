import { Node, useReactFlow } from 'reactflow';
import { useCallback, useRef } from 'react';
import { CommandAddSystems } from '@/hooks/Mapper/types/mapHandlers.ts';
import { convertSystem2Node } from '../../helpers';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

export const useMapAddSystems = () => {
  const rf = useReactFlow();
  const {
    data: { systems },
  } = useMapRootState();

  const ref = useRef({ rf, systems });
  ref.current = { systems, rf };

  return useCallback(
    (systems: CommandAddSystems) => {
      const nodes = rf.getNodes();
      const prepared: Node[] = systems.filter(x => !nodes.some(y => x.id === y.id)).map(convertSystem2Node);
      rf.addNodes(prepared);
    },
    [rf],
  );
};
