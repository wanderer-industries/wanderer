import { useReactFlow } from 'reactflow';
import { useCallback, useRef } from 'react';
import { CommandRemoveSystems } from '@/hooks/Mapper/types/mapHandlers.ts';
import { OnMapSelectionChange } from '@/hooks/Mapper/components/map/map.types.ts';

export const useMapRemoveSystems = (onSelectionChange: OnMapSelectionChange) => {
  const rf = useReactFlow();
  const ref = useRef({ onSelectionChange });
  ref.current = { onSelectionChange };

  return useCallback(
    (systems: CommandRemoveSystems) => {
      rf.deleteElements({ nodes: systems.map(x => ({ id: `${x}` })) });

      const newSelection = rf
        .getNodes()
        .filter(x => !systems.includes(parseInt(x.id)))
        .filter(x => x.selected)
        .map(x => x.id);

      ref.current.onSelectionChange({
        systems: newSelection,
        connections: [],
      });
    },
    [rf],
  );
};
