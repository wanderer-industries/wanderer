import { useReactFlow } from 'reactflow';
import { useCallback, useRef } from 'react';
import { CommandAddConnections, CommandRemoveConnections, CommandUpdateConnection } from '@/hooks/Mapper/types';
import { convertConnection2Edge } from '@/hooks/Mapper/components/map/helpers';

export const useCommandsConnections = () => {
  const rf = useReactFlow();
  const ref = useRef({ rf });
  ref.current = { rf };

  const addConnections = useCallback((systems: CommandAddConnections) => {
    ref.current.rf.addEdges(systems.map(convertConnection2Edge));
  }, []);

  const removeConnections = useCallback((connections: CommandRemoveConnections) => {
    ref.current.rf.deleteElements({ edges: connections.map(x => ({ id: x })) });
  }, []);

  const updateConnection = useCallback((value: CommandUpdateConnection) => {
    ref.current.rf.deleteElements({ edges: [value] });
    ref.current.rf.addEdges([convertConnection2Edge(value)]);
  }, []);

  return { addConnections, removeConnections, updateConnection };
};
