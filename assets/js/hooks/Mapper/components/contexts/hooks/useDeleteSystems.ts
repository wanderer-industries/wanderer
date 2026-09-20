import { OutCommand } from '@/hooks/Mapper/types/mapHandlers.ts';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useRef } from 'react';

export const useDeleteSystems = () => {
  const {
    outCommand,
    data: { systems, connections },
    undoStack: { pushUndoEntry },
  } = useMapRootState();

  const ref = useRef({ systems, connections, pushUndoEntry, outCommand });
  ref.current = { systems, connections, pushUndoEntry, outCommand };

  const deleteSystems = (systemIds: string[]) => {
    if (!systemIds || !systemIds.length) {
      return;
    }

    const { systems, connections, pushUndoEntry, outCommand } = ref.current;

    // snapshot before the server drops them, so the delete can be taken back
    pushUndoEntry({
      systems: systems.filter(system => systemIds.includes(system.id)),
      connections: connections.filter(
        connection => systemIds.includes(connection.source) || systemIds.includes(connection.target),
      ),
    });

    outCommand({ type: OutCommand.deleteSystems, data: systemIds });
  };

  return {
    deleteSystems,
  };
};
