import { MapHandlers } from '@/hooks/Mapper/types/mapHandlers.ts';
import { RefObject, useCallback } from 'react';

// Force reload the page after 30 minutes of inactivity
const FORCE_PAGE_RELOAD_TIMEOUT = 1000 * 60 * 30;

export const useMapperHandlers = (handlerRefs: RefObject<MapHandlers>[], hooksRef: RefObject<any>) => {
  const handleCommand = useCallback(
    async ({ type, data }) => {
      if (!hooksRef.current) {
        return;
      }

      return await hooksRef.current.pushEventAsync(type, data);
    },
    [hooksRef.current],
  );

  const handleMapEvent = useCallback(({ type, body, timestamp }) => {
    const timeDiff = Date.now() - Date.parse(timestamp);
    // If the event is older than the timeout, force reload the page
    if (timeDiff > FORCE_PAGE_RELOAD_TIMEOUT) {
      window.location.reload();
      return;
    }
    handlerRefs.forEach(ref => {
      if (!ref.current) {
        return;
      }

      ref.current?.command(type, body);
    });
  }, []);

  return { handleCommand, handleMapEvent };
};
