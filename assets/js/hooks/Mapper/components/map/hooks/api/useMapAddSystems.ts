import { Node, useReactFlow } from 'reactflow';
import { useCallback, useRef } from 'react';
import { CommandAddSystems } from '@/hooks/Mapper/types/mapHandlers.ts';
import { convertSystem2Node } from '../../helpers';
import { useMapState } from '@/hooks/Mapper/components/map/MapProvider.tsx';

export const useMapAddSystems = () => {
  const rf = useReactFlow();
  const {
    data: { systems },
    update,
  } = useMapState();

  const ref = useRef({ rf, systems, update });
  ref.current = { update, systems, rf };

  return useCallback(
    (systems: CommandAddSystems) => {
      const nodes = rf.getNodes();
      const prepared: Node[] = systems.filter(x => !nodes.some(y => x.id === y.id)).map(convertSystem2Node);
      rf.addNodes(prepared);

      ref.current.update({
        systems: [...ref.current.systems.filter(sys => systems.some(x => sys.id !== x.id)), ...systems],
      });
    },
    [rf],
  );
};
