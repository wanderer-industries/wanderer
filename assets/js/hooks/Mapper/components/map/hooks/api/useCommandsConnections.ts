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
    const newEdge = convertConnection2Edge(value);
    ref.current.rf.setEdges(eds => {
      const exists = eds.find(e => e.id === newEdge.id);
      if (exists) {
        return eds.map(e => e.id === newEdge.id ? newEdge : e);
      } else {
        return [...eds, newEdge];
      }
    });
  }, []);

  return { addConnections, removeConnections, updateConnection };
};
