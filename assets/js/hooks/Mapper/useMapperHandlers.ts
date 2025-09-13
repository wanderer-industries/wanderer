import { useEventBuffer } from '@/hooks/Mapper/hooks';
import usePageVisibility from '@/hooks/Mapper/hooks/usePageVisibility.ts';

import { MapHandlers } from '@/hooks/Mapper/types/mapHandlers.ts';
import { RefObject, useCallback, useEffect, useRef } from 'react';

// const inIndex = 0;
// const prevEventTime = +new Date();
const LAST_VERSION_KEY = 'wandererLastVersion';

// @ts-ignore
export const useMapperHandlers = (handlerRefs: RefObject<MapHandlers>[], hooksRef: RefObject<any>) => {
  const visible = usePageVisibility();

  const wasHiddenOnce = useRef(false);
  const visibleRef = useRef(visible);
  visibleRef.current = visible;

  // @ts-ignore
  const handleBufferedEvent = useCallback(({ type, body }) => {
    if (!visibleRef.current) {
      return;
    }

    handlerRefs.forEach(ref => {
      if (!ref.current) {
        return;
      }

      ref.current?.command(type, body);
    });
  }, []);

  const { handleEvent: handleMapEvent } = useEventBuffer<any>(handleBufferedEvent);

  // TODO - do not delete THIS code it needs for debug
  // const [record, setRecord] = useLocalStorageState<boolean>('record', {
  //   defaultValue: false,
  // });
  // const [recordsList, setRecordsList] = useLocalStorageState<{ type; data }[]>('recordsList', {
  //   defaultValue: [],
  // });
  //
  // const ref = useRef({ record, setRecord, recordsList, setRecordsList });
  // ref.current = { record, setRecord, recordsList, setRecordsList };
  //
  // const recordBufferRef = useRef<{ type; data }[]>([]);
  // useEffect(() => {
  //   if (record || recordBufferRef.current.length === 0) {
  //     return;
  //   }
  //
  //   ref.current.setRecordsList([...recordBufferRef.current]);
  //   recordBufferRef.current = [];
  // }, [record]);

  const handleCommand = useCallback(
    // @ts-ignore
    async ({ type, data }) => {
      if (!hooksRef.current) {
        return;
      }

      // TODO - do not delete THIS code it needs for debug
      // console.log('JOipP', `OUT`, ref.current.record, { type, data });
      // if (ref.current.record) {
      //   recordBufferRef.current.push({ type, data });
      // }

      // 'ui_loaded'
      return await hooksRef.current.pushEventAsync(type, data);
    },
    [hooksRef.current],
  );

  useEffect(() => {
    if (!visible && !wasHiddenOnce.current) {
      wasHiddenOnce.current = true;
      return;
    }

    if (!wasHiddenOnce.current) {
      return;
    }

    if (!visible) {
      return;
    }

    hooksRef.current.pushEventAsync('ui_loaded', { version: localStorage.getItem(LAST_VERSION_KEY) });
  }, [hooksRef.current, visible]);

  return { handleCommand, handleMapEvent };
};
