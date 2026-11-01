import debounce from 'lodash.debounce';
import { useCallback, useEffect, useRef, useState } from 'react';
import type { RefObject } from 'react';
import type {
  PageCharactersHandlers,
  PageCharactersHooks,
  PageCharactersIncomingEvent,
  PageCharactersOutCommandHandler,
} from '../types';
import { PageCharactersOutCommand } from '../types';

const EVENT_BUFFER_DELAY = 10;

const usePageCharactersVisibility = () => {
  const [visible, setVisible] = useState(() => !document.hidden);

  useEffect(() => {
    const handleVisibilityChange = () => setVisible(!document.hidden);
    document.addEventListener('visibilitychange', handleVisibilityChange);

    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  }, []);

  return visible;
};

export const usePageCharactersHandlers = (
  handlerRefs: RefObject<PageCharactersHandlers>[],
  hooksRef: RefObject<PageCharactersHooks>,
) => {
  const visible = usePageCharactersVisibility();
  const wasHiddenOnce = useRef(false);
  const visibleRef = useRef(visible);
  const eventsBufferRef = useRef<PageCharactersIncomingEvent[]>([]);
  visibleRef.current = visible;

  const handleCommand = useCallback<PageCharactersOutCommandHandler>(
    async event => {
      const hooks = hooksRef.current;
      if (!hooks) {
        throw new Error('PageCharacters LiveView hooks are not available.');
      }

      return hooks.pushEventAsync(event.type, event.data);
    },
    [hooksRef],
  );

  const eventTick = useCallback(
    debounce(() => {
      const event = eventsBufferRef.current.shift();
      if (!event) {
        return;
      }

      handlerRefs.forEach(ref => {
        ref.current?.command(event.type, event.body);
      });

      if (eventsBufferRef.current.length > 0) {
        eventTick();
      }
    }, EVENT_BUFFER_DELAY),
    [handlerRefs],
  );
  const eventTickRef = useRef(eventTick);
  eventTickRef.current = eventTick;

  const handlePageCharactersEvent = useCallback((event: PageCharactersIncomingEvent) => {
    if (!visibleRef.current) {
      return;
    }

    eventsBufferRef.current.push(event);
    eventTickRef.current();
  }, []);

  useEffect(() => {
    if (!visible && !wasHiddenOnce.current) {
      wasHiddenOnce.current = true;
      return;
    }

    if (!wasHiddenOnce.current || !visible) {
      return;
    }

    void handleCommand({ type: PageCharactersOutCommand.init, data: {} });
  }, [handleCommand, visible]);

  useEffect(() => {
    return () => {
      eventTick.cancel();
    };
  }, [eventTick]);

  return { handleCommand, handlePageCharactersEvent };
};
