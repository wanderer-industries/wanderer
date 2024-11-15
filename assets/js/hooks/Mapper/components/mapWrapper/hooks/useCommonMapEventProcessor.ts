import { MutableRefObject, useCallback, useEffect, useRef } from 'react';
import { Command, Commands, MapHandlers } from '@/hooks/Mapper/types';
import { MapEvent } from '@/hooks/Mapper/events';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

export const useCommonMapEventProcessor = () => {
  const mapRef = useRef<MapHandlers>() as MutableRefObject<MapHandlers>;
  const {
    data: { systems },
  } = useMapRootState();

  const refQueue = useRef<MapEvent<Command>[]>([]);

  // const ref = useRef({})

  const runCommand = useCallback(({ name, data }: MapEvent<Command>) => {
    switch (name) {
      case Commands.addSystems:
      case Commands.removeSystems:
        // case Commands.addConnections:
        refQueue.current.push({ name, data });
        return;
    }

    // @ts-ignore hz why here type error
    mapRef.current?.command(name, data);
  }, []);

  useEffect(() => {
    refQueue.current.forEach(x => mapRef.current?.command(x.name, x.data));
    refQueue.current = [];
  }, [systems]);

  return {
    mapRef,
    runCommand,
  };
};
