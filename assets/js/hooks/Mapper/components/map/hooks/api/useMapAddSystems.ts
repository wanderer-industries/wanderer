import { Node, useReactFlow } from 'reactflow';
import { useCallback, useRef } from 'react';
import { CommandAddSystems } from '@/hooks/Mapper/types/mapHandlers.ts';
import { convertSystem2Node } from '../../helpers';
import { useLoadSystemStatic } from '@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic';

export const useMapAddSystems = () => {
  const rf = useReactFlow();

  const { addSystemStatic } = useLoadSystemStatic({ systems: [] });

  const ref = useRef({ rf });
  ref.current = { rf };

  return useCallback((systems: CommandAddSystems) => {
    const { rf } = ref.current;
    const nodes = rf.getNodes();

    const newSystems = systems.filter(x => !nodes.some(y => x.id === y.id));
    newSystems.forEach(x => addSystemStatic(x.system_static_info));

    const prepared: Node[] = newSystems.map(convertSystem2Node);
    rf.addNodes(prepared);
  }, []);
};
