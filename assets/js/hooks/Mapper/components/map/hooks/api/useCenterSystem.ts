import { useReactFlow } from 'reactflow';
import { useCallback } from 'react';
import { CommandCenterSystem } from '@/hooks/Mapper/types';

export const useCenterSystem = () => {
  const rf = useReactFlow();

  return useCallback((systemId: CommandCenterSystem) => {
    if (!rf) {
      return;
    }
    const systemNode = rf.getNodes().find(x => x.data.id === systemId);
    if (!systemNode) {
      return;
    }
    rf.setCenter(systemNode.position.x, systemNode.position.y, { duration: 1000 });
  }, []);
};
