import { useCallback } from 'react';
import { CommandInit } from '@/hooks/Mapper/types';
import { MapRootData, useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useLoadSystemStatic } from '@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic.ts';

export const useMapInit = () => {
  const { update } = useMapRootState();

  const { addSystemStatic } = useLoadSystemStatic({ systems: [] });

  return useCallback(
    ({
      systems,
      connections,
      effects,
      wormholes,
      system_static_infos,
      characters,
      user_characters,
      present_characters,
      hubs,
      user_permissions,
      options,
      is_subscription_active,
    }: CommandInit) => {
      const updateData: Partial<MapRootData> = {};

      if (wormholes) {
        updateData.wormholesData = wormholes.reduce((acc, x) => ({ ...acc, [x.name]: x }), {});
        updateData.wormholes = wormholes;
      }

      if (effects) {
        updateData.effects = effects.reduce((acc, x) => ({ ...acc, [x.name]: x }), {});
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

      if (systems) {
        updateData.systems = systems;
      }

      if (connections) {
        updateData.connections = connections;
      }

      if (user_permissions) {
        updateData.userPermissions = user_permissions;
      }

      if (hubs) {
        updateData.hubs = hubs;
      }

      if (options) {
        updateData.options = options;
      }

      updateData.isSubscriptionActive = is_subscription_active;

      if (system_static_infos) {
        system_static_infos.forEach(static_info => {
          addSystemStatic(static_info);
        });
      }

      update(updateData);
    },
    [update, addSystemStatic],
  );
};
