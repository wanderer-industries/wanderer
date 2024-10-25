import { Node, useReactFlow } from 'reactflow';
import { useCallback, useRef } from 'react';
import { CommandAddSystems } from '@/hooks/Mapper/types/mapHandlers.ts';
import { convertSystem2Node } from '../../helpers';

export const useMapAddSystems = () => {
  const rf = useReactFlow();

  const ref = useRef({ rf });
  ref.current = { rf };

  return useCallback((systems: CommandAddSystems) => {
    const { rf } = ref.current;
    const nodes = rf.getNodes();
    const prepared: Node[] = systems.filter(x => !nodes.some(y => x.id === y.id)).map(convertSystem2Node);
    rf.addNodes(prepared);
  }, []);
};
