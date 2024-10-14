import { useReactFlow } from 'reactflow';
import { useCallback, useRef } from 'react';
import { CommandSelectSystem } from '@/hooks/Mapper/types';

export const useSelectSystem = () => {
  const rf = useReactFlow();

  const ref = useRef({ rf });
  ref.current = { rf };

  return useCallback((systemId: CommandSelectSystem) => {
    ref.current.rf.setNodes(nds =>
      nds.map(node => {
        return {
          ...node,
          selected: node.id === systemId,
        };
      }),
    );
  }, []);
};
