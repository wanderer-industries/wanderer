import { useReactFlow } from 'reactflow';
import { useCallback } from 'react';
import { CommandSelectSystem } from '@/hooks/Mapper/types';

export const useSelectSystem = () => {
  const rf = useReactFlow();

  return useCallback((systemId: CommandSelectSystem) => {
    if (!rf) {
      return;
    }
    rf.setNodes(nds =>
      nds.map(node => {
        return {
          ...node,
          selected: node.id === systemId,
        };
      }),
    );
  }, []);
};
