import { useEffect, useState, useCallback } from 'react';
import { useMapEventListener } from '@/hooks/Mapper/events';
import { Commands } from '@/hooks/Mapper/types';

interface Kill {
  solar_system_id: number | string;
  kills: number;
}

interface MapEvent {
  name: Commands;
  data?: any;
  payload?: Kill[];
}

export function useNodeKillsCount(
  systemId: number | string,
  initialKillsCount: number | null
): number | null {
  const [killsCount, setKillsCount] = useState<number | null>(initialKillsCount);

  useEffect(() => {
    setKillsCount(initialKillsCount);
  }, [initialKillsCount]);

  const handleEvent = useCallback((event: MapEvent): boolean => {
    if (event.name === Commands.killsUpdated && Array.isArray(event.payload)) {
      const killForSystem = event.payload.find(
        kill => kill.solar_system_id.toString() === systemId.toString()
      );
      if (killForSystem && typeof killForSystem.kills === 'number') {
        setKillsCount(killForSystem.kills);
      }
      return true;
    }
    return false;
  }, [systemId]);

  useMapEventListener(handleEvent);

  return killsCount;
}
