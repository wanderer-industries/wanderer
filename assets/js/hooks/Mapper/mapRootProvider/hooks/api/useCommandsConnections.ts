import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback, useRef } from 'react';
import { CommandAddConnections, CommandRemoveConnections, CommandUpdateConnection } from '@/hooks/Mapper/types';

export const useCommandsConnections = () => {
  const {
    update,
    data: { connections },
  } = useMapRootState();

  const ref = useRef({ update, connections });
  ref.current = { update, connections };

  const addConnections = useCallback((toAdd: CommandAddConnections) => {
    const { update, connections } = ref.current;
    update({
      connections: [...connections, ...toAdd],
    });
  }, []);

  const removeConnections = useCallback((toRemove: CommandRemoveConnections) => {
    const { update, connections } = ref.current;
    update({
      connections: connections.filter(x => !toRemove.includes(x.id)),
    });
  }, []);

  const updateConnection = useCallback((newConn: CommandUpdateConnection) => {
    const { update, connections } = ref.current;

    update({
      connections: [...connections.filter(x => x.id !== newConn.id), newConn],
    });
  }, []);

  return { addConnections, removeConnections, updateConnection };
};
