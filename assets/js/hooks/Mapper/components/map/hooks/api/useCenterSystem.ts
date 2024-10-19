import { useReactFlow } from 'reactflow';
import { useCallback, useRef } from 'react';
import { CommandCenterSystem } from '@/hooks/Mapper/types';

export const useCenterSystem = () => {
  const rf = useReactFlow();

  const ref = useRef({ rf });
  ref.current = { rf };

  return useCallback((systemId: CommandCenterSystem) => {
    const systemNode = ref.current.rf.getNodes().find(x => x.data.id === systemId);
    if (!systemNode) {
      return;
    }
    ref.current.rf.setCenter(systemNode.position.x, systemNode.position.y, { duration: 1000 });
  }, []);
};
