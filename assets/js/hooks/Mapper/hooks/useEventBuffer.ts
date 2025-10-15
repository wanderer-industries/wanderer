import debounce from 'lodash.debounce';
import { useCallback, useRef } from 'react';
export type UseEventBufferHandler<T> = (event: T) => void;

export const useEventBuffer = <T>(handler: UseEventBufferHandler<T>) => {
  // @ts-ignore
  const eventsBufferRef = useRef<T[]>([]);

  const eventTick = useCallback(
    debounce(() => {
      if (eventsBufferRef.current.length === 0) {
        return;
      }

      const event = eventsBufferRef.current.shift()!;
      handler(event);

      // TODO - do not delete THIS code it needs for debug
      // console.log('JOipP', `Tick Buff`, eventsBufferRef.current.length);

      if (eventsBufferRef.current.length > 0) {
        eventTick();
      }
    }, 10),
    [],
  );
  const eventTickRef = useRef(eventTick);
  eventTickRef.current = eventTick;

  // @ts-ignore
  const handleEvent = useCallback(
    event => {
      if (!eventTickRef.current) {
        return;
      }

      eventsBufferRef.current.push(event);
      eventTickRef.current();
    },
    [eventTickRef.current],
  );

  return { handleEvent };
};
