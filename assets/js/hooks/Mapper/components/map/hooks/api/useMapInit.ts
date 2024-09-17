import { useReactFlow } from 'reactflow';
import { useCallback, useRef } from 'react';
import { CommandInit } from '@/hooks/Mapper/types/mapHandlers.ts';
import { convertConnection2Edge, convertSystem2Node } from '../../helpers';
import { MapData, useMapState } from '@/hooks/Mapper/components/map/MapProvider.tsx';

export const useMapInit = () => {
  const rf = useReactFlow();
  const { data, update } = useMapState();

  const ref = useRef({ rf, data, update });
  ref.current = { update, data, rf };

  return useCallback(
    ({
      systems,
      kills,
      connections,
      wormholes,
      characters,
      user_characters,
      present_characters,
      hubs,
    }: CommandInit) => {
      const { update } = ref.current;
      const { rf } = ref.current;

      const updateData: Partial<MapData> = {};

      if (wormholes) {
        updateData.wormholesData = wormholes.reduce((acc, x) => ({ ...acc, [x.name]: x }), {});
      }

      if (characters) {
        updateData.characters = characters.slice();
      }

      if (user_characters) {
        updateData.userCharacters = user_characters;
      }

      if (present_characters) {
        updateData.presentCharacters = present_characters;
      }

      if (hubs) {
        updateData.hubs = hubs;
      }

      if (systems) {
        updateData.systems = systems;
      }

      if (kills) {
        updateData.kills = kills.reduce((acc, x) => ({ ...acc, [x.solar_system_id]: x.kills }), {});
      }

      update(updateData);

      if (systems) {
        rf.setNodes(systems.map(convertSystem2Node));
      }

      if (connections) {
        rf.setEdges(connections.map(convertConnection2Edge));
      }
    },
    [],
  );
};
