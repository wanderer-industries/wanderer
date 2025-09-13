import { MapEvent } from '@/hooks/Mapper/events';
// import { useThrottle } from '@/hooks/Mapper/hooks';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { Command, Commands, MapHandlers } from '@/hooks/Mapper/types';
import { MutableRefObject, useCallback, useEffect, useRef } from 'react';

export const useCommonMapEventProcessor = () => {
  const mapRef = useRef<MapHandlers>() as MutableRefObject<MapHandlers>;
  const {
    data: { systems },
  } = useMapRootState();

  const refQueue = useRef<MapEvent<Command>[]>([]);

  const runCommand = useCallback(({ name, data }: MapEvent<Command>) => {
    switch (name) {
      case Commands.addSystems:
      case Commands.removeSystems:
        // case Commands.updateSystems:
        // case Commands.addConnections:
        // case Commands.removeConnections:
        // case Commands.updateConnection:
        refQueue.current.push({ name, data });
        return;
    }

    // @ts-ignore hz why here type error
    mapRef.current?.command(name, data);
  }, []);

  const processQueue = useCallback(() => {
    const commands = [...refQueue.current];
    refQueue.current = [];
    commands.forEach(x => mapRef.current?.command(x.name, x.data));
  }, []);

  // const throttledProcessQueue = useThrottle(processQueue, 200);

  useEffect(() => {
    // throttledProcessQueue();
    processQueue();
  }, [systems]);

  return {
    mapRef,
    runCommand,
  };
};
