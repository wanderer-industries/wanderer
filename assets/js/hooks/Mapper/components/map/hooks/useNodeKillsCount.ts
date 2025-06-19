import { useEffect, useState, useCallback, useMemo } from 'react';
import { useMapEventListener } from '@/hooks/Mapper/events';
import { Commands } from '@/hooks/Mapper/types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

interface Kill {
  solar_system_id: number | string;
  kills: number;
}

interface MapEvent {
  name: Commands;
  data?: unknown;
  payload?: Kill[];
}

export function useNodeKillsCount(systemId: number | string, initialKillsCount: number | null): number | null {
  const [killsCount, setKillsCount] = useState<number | null>(initialKillsCount);
  const { data: mapData } = useMapRootState();
  const { detailedKills = {} } = mapData;

  // Calculate 1-hour kill count from detailed kills
  const oneHourKillCount = useMemo(() => {
    const systemKills = detailedKills[systemId] || [];
    if (systemKills.length === 0) return null;

    const oneHourAgo = Date.now() - 60 * 60 * 1000; // 1 hour in milliseconds
    const recentKills = systemKills.filter(kill => {
      if (!kill.kill_time) return false;
      const killTime = new Date(kill.kill_time).getTime();
      if (isNaN(killTime)) return false;
      return killTime >= oneHourAgo;
    });

    return recentKills.length > 0 ? recentKills.length : null;
  }, [detailedKills, systemId]);

  useEffect(() => {
    // Use 1-hour count if available, otherwise fall back to initial count
    setKillsCount(oneHourKillCount !== null ? oneHourKillCount : initialKillsCount);
  }, [oneHourKillCount, initialKillsCount]);

  const handleEvent = useCallback(
    (event: MapEvent): boolean => {
      if (event.name === Commands.killsUpdated && Array.isArray(event.payload)) {
        const killForSystem = event.payload.find(kill => kill.solar_system_id.toString() === systemId.toString());
        if (killForSystem && typeof killForSystem.kills === 'number') {
          // Only update if we don't have detailed kills data
          if (!detailedKills[systemId] || detailedKills[systemId].length === 0) {
            setKillsCount(killForSystem.kills);
          }
        }
        return true;
      }
      return false;
    },
    [systemId, detailedKills],
  );

  useMapEventListener(handleEvent);

  return killsCount;
}
