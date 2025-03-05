import { RefObject, useCallback } from 'react';
import { Command, MapHandlers } from '@/hooks/Mapper/types/mapHandlers.ts';

export const useMapperHandlers = (handlerRefs: RefObject<MapHandlers>[], hooksRef: RefObject<any>) => {
  const handleCommand = useCallback(
    async ({ type, data }: { type: string; data: any }) => {
      if (!hooksRef.current) {
        return;
      }

      return await hooksRef.current.pushEventAsync(type, data);
    },
    [hooksRef.current],
  );

  const handleMapEvent = useCallback(({ type, body }: { type: Command; body: any }) => {
    handlerRefs.forEach(ref => {
      if (!ref.current) {
        return;
      }

      ref.current?.command(type, body);
    });
  }, []);

  const handleMapEvents = useCallback(
    (events: any[]) => {
      events.forEach(event => {
        handleMapEvent(event);
      });
    },
    [handleMapEvent],
  );

  return { handleCommand, handleMapEvent, handleMapEvents };
};
