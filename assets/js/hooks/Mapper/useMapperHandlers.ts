import { RefObject, useCallback, useEffect, useRef } from 'react';

import { MapHandlers } from '@/hooks/Mapper/types/mapHandlers.ts';
import { usePageVisibility } from '@/hooks/Mapper/hooks';

const COLLECTING_COUNT_EVENT_LIMIT = 100;
type MapEventIn = { type: never; body: never };

export const useMapperHandlers = (handlerRefs: RefObject<MapHandlers>[], hooksRef: RefObject<any>) => {
  const isVisible = usePageVisibility();

  const isVisibleRef = useRef(isVisible);
  isVisibleRef.current = isVisible;

  const eventsCollectorRef = useRef<MapEventIn[]>([]);

  const handleCommand = useCallback(
    // @ts-ignore
    async ({ type, data }) => {
      if (!hooksRef.current) {
        return;
      }

      return await hooksRef.current.pushEventAsync(type, data);
    },
    [hooksRef.current],
  );

  const handleMapEvent = useCallback(({ type, body }: MapEventIn) => {
    if (!isVisibleRef.current) {
      eventsCollectorRef.current.push({ type, body });
      return;
    }

    handlerRefs.forEach(ref => {
      if (!ref.current) {
        return;
      }

      ref.current?.command(type, body);
    });
  }, []);

  const handleMapEvents = useCallback(
    (events: MapEventIn[]) => {
      events.forEach(event => {
        handleMapEvent(event);
      });
    },
    [handleMapEvent],
  );

  useEffect(() => {
    if (!isVisible || eventsCollectorRef.current.length === 0) {
      return;
    }

    if (eventsCollectorRef.current.length >= COLLECTING_COUNT_EVENT_LIMIT) {
      handleCommand({ type: 'force_reset', data: {} });
      eventsCollectorRef.current = [];
      return;
    }

    handleMapEvents([...eventsCollectorRef.current]);
    eventsCollectorRef.current = [];
  }, [handleCommand, handleMapEvents, isVisible]);

  return { handleCommand, handleMapEvent, handleMapEvents };
};
