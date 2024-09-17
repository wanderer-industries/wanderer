import { useReactFlow } from 'reactflow';
import { useCallback, useRef } from 'react';
import { CommandSelectSystem } from '@/hooks/Mapper/types';

export const useSelectSystem = () => {
  const rf = useReactFlow();
  const ref = useRef({ rf });
  ref.current = { rf };

  return useCallback((systemId: CommandSelectSystem) => {
    if (!ref.current?.rf) {
      return;
    }
    const systemNode = ref.current.rf.getNodes().find(x => x.data.id === systemId);
    if (!systemNode) {
      return;
    }

    ref.current.rf.setCenter(systemNode.position.x, systemNode.position.y, { duration: 1000 });
  }, []);
};
