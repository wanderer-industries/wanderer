import { RefObject, useCallback } from 'react';

import { MapHandlers } from '@/hooks/Mapper/types/mapHandlers.ts';

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

  const handleMapEvent = useCallback(({ type, body }) => {
    handlerRefs.forEach(ref => {
      if (!ref.current) {
        return;
      }

      ref.current?.command(type, body);
    });
  }, []);

  const handleMapEvents = useCallback(
    events => {
      events.forEach(event => {
        handleMapEvent(event);
      });
    },
    [handleMapEvent],
  );

  return { handleCommand, handleMapEvent, handleMapEvents };
};
