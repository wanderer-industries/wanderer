import { useReactFlow } from 'reactflow';
import { useCallback, useRef } from 'react';
import { CommandRemoveSystems } from '@/hooks/Mapper/types/mapHandlers.ts';
import { OnMapSelectionChange } from '@/hooks/Mapper/components/map/map.types.ts';

export const useMapRemoveSystems = (onSelectionChange: OnMapSelectionChange) => {
  const rf = useReactFlow();
  const ref = useRef({ onSelectionChange, rf });
  ref.current = { onSelectionChange, rf };

  return useCallback((systems: CommandRemoveSystems) => {
    ref.current.rf.deleteElements({ nodes: systems.map(x => ({ id: `${x}` })) });

    const newSelection = ref.current.rf
      .getNodes()
      .filter(x => !systems.includes(parseInt(x.id)))
      .filter(x => x.selected)
      .map(x => x.id);

    ref.current.onSelectionChange({
      systems: newSelection,
      connections: [],
    });
  }, []);
};
