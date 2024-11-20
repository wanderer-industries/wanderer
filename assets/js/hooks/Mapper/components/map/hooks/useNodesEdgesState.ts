import { useCallback, type Dispatch, type SetStateAction, useEffect } from 'react';
import { atom, useAtom } from 'jotai';

import { SolarSystemConnection, SolarSystemRawType } from '@/hooks/Mapper/types';

import { applyNodeChanges, applyEdgeChanges } from '../utils/changes';
import { OnNodesChange, Edge, OnEdgesChange, Node } from 'reactflow';

const nodesAtom = atom<Node<SolarSystemRawType>[]>([]);
const edgesAtom = atom<Edge<SolarSystemConnection>[]>([]);

/**
 * Hook for managing the state of nodes.
 *
 * @public
 * @param initialNodes
 * @returns an array [nodes, setNodes, onNodesChange]
 */
export function useNodesState(
  initialNodes: Node<SolarSystemRawType>[],
): [Node<SolarSystemRawType>[], Dispatch<SetStateAction<Node<SolarSystemRawType>[]>>, OnNodesChange] {
  const [nodes, setNodes] = useAtom(nodesAtom);
  const onNodesChange: OnNodesChange = useCallback(changes => setNodes(nds => applyNodeChanges(changes, nds)), []);

  useEffect(() => {
    setNodes(initialNodes);
  }, []);

  return [nodes, setNodes, onNodesChange];
}

/**
 * Hook for managing the state of edges.
 *
 * @public
 * @param initialEdges
 * @returns an array [edges, setEdges, onEdgesChange]
 */
export function useEdgesState(
  initialEdges: Edge<SolarSystemConnection>[],
): [Edge<SolarSystemConnection>[], Dispatch<SetStateAction<Edge<SolarSystemConnection>[]>>, OnEdgesChange] {
  const [edges, setEdges] = useAtom(edgesAtom);
  const onEdgesChange: OnEdgesChange = useCallback(changes => setEdges(eds => applyEdgeChanges(changes, eds)), []);

  useEffect(() => {
    setEdges(initialEdges);
  }, []);

  return [edges, setEdges, onEdgesChange];
}
