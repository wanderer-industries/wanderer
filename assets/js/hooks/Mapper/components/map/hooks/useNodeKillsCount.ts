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

function getActivityType(count: number): string {
  if (count <= 5) return 'activityNormal';
  if (count <= 30) return 'activityWarn';
  return 'activityDanger';
}

export function useNodeKillsCount(systemId: number | string, initialKillsCount: number | null = null): { killsCount: number | null; killsActivityType: string | null } {
  const [killsCount, setKillsCount] = useState<number | null>(initialKillsCount);
  const { data: mapData } = useMapRootState();
  const { detailedKills = {} } = mapData;

  // Calculate 1-hour kill count from detailed kills
  const oneHourKillCount = useMemo(() => {
    const systemKills = detailedKills[systemId] || [];

    // If we have detailed kills data (even if empty), use it for counting
    if (Object.prototype.hasOwnProperty.call(detailedKills, systemId)) {
      const oneHourAgo = Date.now() - 60 * 60 * 1000; // 1 hour in milliseconds
      const recentKills = systemKills.filter(kill => {
        if (!kill.kill_time) return false;
        const killTime = new Date(kill.kill_time).getTime();
        if (isNaN(killTime)) return false;
        return killTime >= oneHourAgo;
      });

      return recentKills.length; // Return 0 if no recent kills, not null
    }

    // Return null only if we don't have detailed kills data for this system
    return null;
  }, [detailedKills, systemId]);

  useEffect(() => {
    // Always prefer the calculated 1-hour count over initial count
    // This ensures we properly expire old kills
    if (oneHourKillCount !== null) {
      setKillsCount(oneHourKillCount);
    } else if (detailedKills[systemId] && detailedKills[systemId].length === 0) {
      // If we have detailed kills data but it's empty, set to 0
      setKillsCount(0);
    } else {
      // Only fall back to initial count if we have no detailed kills data at all
      setKillsCount(initialKillsCount);
    }
  }, [oneHourKillCount, initialKillsCount, detailedKills, systemId]);

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

  const killsActivityType = useMemo(() => {
    return killsCount !== null && killsCount > 0 ? getActivityType(killsCount) : null;
  }, [killsCount]);

  return { killsCount, killsActivityType };
}
