import { OnMapSelectionChange } from '@/hooks/Mapper/components/map/map.types.ts';
import { CommandSelectSystems } from '@/hooks/Mapper/types';
import { useCallback, useRef } from 'react';
import { useReactFlow } from 'reactflow';

export const useSelectSystems = (onSelectionChange: OnMapSelectionChange) => {
  const rf = useReactFlow();

  const ref = useRef({ rf, onSelectionChange });
  ref.current = { rf, onSelectionChange };

  return useCallback(({ systems, delay }: CommandSelectSystems) => {
    const run = () => {
      ref.current.rf.setNodes(nds =>
        nds.map(node => {
          return {
            ...node,
            selected: systems.includes(node.id),
          };
        }),
      );
    };

    if (delay == null || delay === 0) {
      run();
      return;
    }

    setTimeout(run, delay);
  }, []);
};
