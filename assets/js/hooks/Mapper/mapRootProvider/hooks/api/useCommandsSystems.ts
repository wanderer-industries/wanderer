import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback, useRef } from 'react';
import { CommandAddSystems, CommandRemoveSystems, CommandUpdateSystems } from '@/hooks/Mapper/types';
import { useLoadSystemStatic } from '@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic.ts';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers.ts';
import { emitMapEvent } from '@/hooks/Mapper/events';
import { Commands } from '@/hooks/Mapper/types/mapHandlers.ts';
export const useCommandsSystems = () => {
  const {
    update,
    data: { systems, systemSignatures },
    outCommand,
  } = useMapRootState();

  const { addSystemStatic } = useLoadSystemStatic({ systems: [] });

  const ref = useRef({ systems, systemSignatures, update, addSystemStatic });
  ref.current = { systems, systemSignatures, update, addSystemStatic };

  const addSystems = useCallback((systemsToAdd: CommandAddSystems) => {
    const { update, addSystemStatic, systems } = ref.current;

    systemsToAdd.forEach(sys => {
      if (sys.system_static_info) {
        addSystemStatic(sys.system_static_info);
      }
    });

    update(
      {
        systems: [...systems.filter(sys => !systemsToAdd.some(x => sys.id === x.id)), ...systemsToAdd],
      },
      true,
    );
  }, []);

  const removeSystems = useCallback((toRemove: CommandRemoveSystems) => {
    const { update, systems } = ref.current;
    update(
      {
        systems: systems.filter(x => !toRemove.includes(parseInt(x.id))),
      },
      true,
    );
  }, []);

  const updateSystems = useCallback((updatedSystems: CommandUpdateSystems) => {
    const { update, systems } = ref.current;

    const out = systems.map(current => {
      const newSystem = updatedSystems.find(x => current.id === x.id);
      if (!newSystem) {
        return current;
      }

      return newSystem;
    });

    update({ systems: out }, true);

    emitMapEvent({ name: Commands.updateSystems, data: out });
  }, []);

  const updateSystemSignatures = useCallback(
    async (systemId: string) => {
      const { update, systemSignatures } = ref.current;
      const { signatures } = await outCommand({
        type: OutCommand.getSignatures,
        data: { system_id: `${systemId}` },
      });
      const out = { ...systemSignatures, [`${systemId}`]: signatures };
      update({ systemSignatures: out }, true);
    },
    [outCommand],
  );

  return { addSystems, removeSystems, updateSystems, updateSystemSignatures };
};
