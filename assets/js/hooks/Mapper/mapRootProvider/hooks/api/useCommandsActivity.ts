import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback, useRef } from 'react';
import {
  CommandCharacterActivityData,
  CommandTrackingCharactersData,
  CommandUserSettingsUpdated,
  Commands,
} from '@/hooks/Mapper/types/mapHandlers';
import { MapRootData } from '@/hooks/Mapper/mapRootProvider/MapRootProvider';
import { emitMapEvent } from '@/hooks/Mapper/events';

export const useCommandsActivity = () => {
  const { update } = useMapRootState();

  const ref = useRef({ update });
  ref.current = { update };

  const characterActivityData = useCallback((data: CommandCharacterActivityData) => {
    try {
      ref.current.update((state: MapRootData) => ({
        ...state,
        characterActivityData: {
          activity: data.activity,
          loading: data.loading,
        },
        showCharacterActivity: true,
      }));
    } catch (error) {
      console.error('Failed to process character activity data:', error);
    }
  }, []);

  const trackingCharactersData = useCallback((data: CommandTrackingCharactersData) => {
    ref.current.update((state: MapRootData) => ({
      ...state,
      trackingCharactersData: data.characters,
      showTrackAndFollow: true,
    }));
  }, []);

  const hideActivity = useCallback(() => {
    ref.current.update((state: MapRootData) => ({
      ...state,
      showCharacterActivity: false,
    }));
  }, []);

  const userSettingsUpdated = useCallback((data: CommandUserSettingsUpdated) => {
    emitMapEvent({ name: Commands.userSettingsUpdated, data });
  }, []);

  return { characterActivityData, trackingCharactersData, userSettingsUpdated, hideActivity };
};
