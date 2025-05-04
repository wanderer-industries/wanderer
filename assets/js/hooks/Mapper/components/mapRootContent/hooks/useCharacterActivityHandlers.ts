import { useCallback } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { ActivitySummary } from '@/hooks/Mapper/types';

/**
 * Hook for character activity related handlers
 */
export const useCharacterActivityHandlers = () => {
  const { outCommand, update } = useMapRootState();

  /**
   * Handle hiding the character activity dialog
   */
  const handleHideCharacterActivity = useCallback(() => {
    // Update local state to hide the dialog
    update(state => ({
      ...state,
      showCharacterActivity: false,
    }));
  }, [update]);

  /**
   * Handle showing the character activity dialog
   */
  const handleShowActivity = useCallback(() => {
    // Update local state to show the dialog
    update(state => ({
      ...state,
      showCharacterActivity: true,
    }));

    // Send the command to the server
    outCommand({
      type: OutCommand.showActivity,
      data: {},
    });
  }, [outCommand, update]);

  /**
   * Handle updating character activity data
   */
  const handleUpdateActivity = useCallback(
    (activityData: { activity: ActivitySummary[] }) => {
      if (!activityData || !activityData.activity) {
        console.error('Invalid activity data received:', activityData);
        return;
      }

      // Update local state with the activity data
      update(state => ({
        ...state,
        characterActivityData: activityData,
        showCharacterActivity: true,
      }));
    },
    [update],
  );

  return {
    handleHideCharacterActivity,
    handleShowActivity,
    handleUpdateActivity,
  };
};
