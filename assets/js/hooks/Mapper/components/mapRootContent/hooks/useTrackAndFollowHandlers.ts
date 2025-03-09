import { useCallback } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { OutCommand, CommandData, Commands } from '@/hooks/Mapper/types/mapHandlers';
import type { TrackingCharacter } from '@/hooks/Mapper/components/mapRootContent/components/TrackAndFollow/types';

/**
 * Hook for track and follow related handlers
 */
export const useTrackAndFollowHandlers = () => {
  const { outCommand, update } = useMapRootState();

  /**
   * Handle hiding the track and follow dialog
   */
  const handleHideTracking = useCallback(() => {
    // Update local state to hide the dialog
    update(state => ({
      ...state,
      showTrackAndFollow: false,
    }));

    // Send the command to the server
    outCommand({
      type: OutCommand.hideTracking,
      data: {},
    });
  }, [outCommand, update]);

  /**
   * Handle showing the track and follow dialog
   */
  const handleShowTracking = useCallback(() => {
    // Update local state to show the dialog
    update(state => ({
      ...state,
      showTrackAndFollow: true,
    }));

    // Send the command to the server
    outCommand({
      type: OutCommand.showTracking,
      data: {},
    });
  }, [outCommand, update]);

  /**
   * Handle updating tracking data
   */
  const handleUpdateTracking = useCallback(
    (trackingData: { characters: TrackingCharacter[] }) => {
      if (!trackingData || !trackingData.characters) {
        console.error('Invalid tracking data received:', trackingData);
        return;
      }

      // Update local state with the tracking data
      update(state => ({
        ...state,
        trackingCharactersData: trackingData.characters,
        showTrackAndFollow: true,
      }));
    },
    [update],
  );

  /**
   * Handle toggling character tracking
   */
  const handleToggleTrack = useCallback(
    (characterId: string) => {
      if (!characterId) return;

      // Send the toggle track command to the server
      outCommand({
        type: OutCommand.toggleTrack,
        data: { 'character-id': characterId },
      });

      // Note: The local state is now updated in the TrackAndFollow component
      // for immediate UI feedback, while we wait for the server response
    },
    [outCommand],
  );

  /**
   * Handle toggling character following
   */
  const handleToggleFollow = useCallback(
    (characterId: string) => {
      if (!characterId) return;

      // Send the toggle follow command to the server
      outCommand({
        type: OutCommand.toggleFollow,
        data: { 'character-id': characterId },
      });

      // Note: The local state is now updated in the TrackAndFollow component
      // for immediate UI feedback, while we wait for the server response
    },
    [outCommand],
  );


  /**
   * Handle user settings updates
   */
  const handleUserSettingsUpdated = useCallback((settingsData: CommandData[Commands.userSettingsUpdated]) => {
    if (!settingsData || !settingsData.settings) {
      console.error('Invalid settings data received:', settingsData);
    }
  }, []);

  return {
    handleHideTracking,
    handleShowTracking,
    handleUpdateTracking,
    handleToggleTrack,
    handleToggleFollow,
    handleUserSettingsUpdated,
  };
};
