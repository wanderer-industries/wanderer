import { useMemo } from 'react';
import { useSystemKills } from '../../mapInterface/widgets/SystemKills/hooks/useSystemKills';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

interface UseKillsCounterProps {
  realSystemId: string;
}

export function useKillsCounter({ realSystemId }: UseKillsCounterProps) {
  const { data: mapData, outCommand } = useMapRootState();
  const { systems } = mapData;

  const systemNameMap = useMemo(() => {
    const m: Record<string, string> = {};
    systems.forEach(sys => {
      m[sys.id] = sys.temporary_name || sys.name || '???';
    });
    return m;
  }, [systems]);

  const { kills: allKills, isLoading } = useSystemKills({
    systemId: realSystemId,
    outCommand,
    showAllVisible: false,
  });

  const filteredKills = useMemo(() => {
    if (!allKills || allKills.length === 0) return [];

    // Sort kills by time, most recent first, but don't limit the number of kills
    return [...allKills].sort((a, b) => {
      const aTime = a.kill_time ? new Date(a.kill_time).getTime() : 0;
      const bTime = b.kill_time ? new Date(b.kill_time).getTime() : 0;
      return bTime - aTime;
    });
  }, [allKills]);

  return {
    isLoading,
    kills: filteredKills,
    systemNameMap,
  };
}
