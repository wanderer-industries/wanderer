import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback, useRef } from 'react';
import { CommandAddSystems, CommandRemoveSystems, CommandUpdateSystems } from '@/hooks/Mapper/types';

export const useCommandsSystems = () => {
  const {
    update,
    data: { systems },
  } = useMapRootState();

  const ref = useRef({ systems, update });
  ref.current = { systems, update };

  const addSystems = useCallback(
    (addSystems: CommandAddSystems) => {
      update({
        systems: [...ref.current.systems.filter(sys => addSystems.some(x => sys.id !== x.id)), ...addSystems],
      });
    },
    [update],
  );

  const removeSystems = useCallback((toRemove: CommandRemoveSystems) => {
    const { update, systems } = ref.current;
    update({
      systems: systems.filter(x => !toRemove.includes(parseInt(x.id))),
    });
  }, []);

  const updateSystems = useCallback(
    (systems: CommandUpdateSystems) => {
      const out = ref.current.systems.map(current => {
        const newSystem = systems.find(x => current.id === x.id);
        if (!newSystem) {
          return current;
        }

        return newSystem;
      });

      update({ systems: out });
    },
    [update],
  );

  return { addSystems, removeSystems, updateSystems };
};
