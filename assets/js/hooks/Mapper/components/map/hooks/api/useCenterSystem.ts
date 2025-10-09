import { useReactFlow } from 'reactflow';
import { useCallback, useRef } from 'react';
import { CommandCenterSystem } from '@/hooks/Mapper/types';
import { useMapState } from '@/hooks/Mapper/components/map/MapProvider.tsx';
import { SYSTEM_FOCUSED_LIFETIME } from '@/hooks/Mapper/constants.ts';

export const useCenterSystem = () => {
  const rf = useReactFlow();

  const { update } = useMapState();

  const ref = useRef({ rf, update });
  ref.current = { rf, update };

  const highlightTimeout = useRef<number>();

  return useCallback((systemId: CommandCenterSystem) => {
    const systemNode = ref.current.rf.getNodes().find(x => x.data.id === systemId);
    if (!systemNode) {
      return;
    }
    ref.current.rf.setCenter(systemNode.position.x, systemNode.position.y, { duration: 1000 });

    ref.current.update({ systemHighlighted: systemId });

    if (highlightTimeout.current !== undefined) {
      clearTimeout(highlightTimeout.current);
    }

    highlightTimeout.current = setTimeout(() => {
      highlightTimeout.current = undefined;
      ref.current.update({ systemHighlighted: undefined });
    }, SYSTEM_FOCUSED_LIFETIME);
  }, []);
};
