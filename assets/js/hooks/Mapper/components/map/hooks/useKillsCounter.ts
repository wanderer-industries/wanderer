import { useMemo, useState } from 'react';
import { useSystemKills } from '../../mapInterface/widgets/SystemKills/hooks/useSystemKills';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

interface UseKillsCounterProps {
  realSystemId: string;
}

export function useKillsCounter({ realSystemId }: UseKillsCounterProps) {
  const { data: mapData, outCommand } = useMapRootState();
  const { systems } = mapData;

  const [isHovered, setIsHovered] = useState(false);
  const handleMouseEnter = () => setIsHovered(true);
  const handleMouseLeave = () => setIsHovered(false);

  const systemNameMap = useMemo(() => {
    const m: Record<string, string> = {};
    systems.forEach(sys => {
      m[sys.id] = sys.temporary_name || sys.name || '???';
    });
    return m;
  }, [systems]);

  const systemIdForHook = useMemo(() => {
    return isHovered ? realSystemId : undefined;
  }, [isHovered, realSystemId]);

  const { kills: allKills, isLoading } = useSystemKills({
    systemId: systemIdForHook,
    outCommand,
    showAllVisible: false,
  });

  const filteredKills = useMemo(() => {
    return allKills.filter(kill => {
      if (!kill.kill_time) return false;
      const killTimeMs = new Date(kill.kill_time).getTime();
      const timePeriod = Date.now() - 60 * 60 * 1000 * 2;
      return killTimeMs >= timePeriod;
    });
  }, [allKills]);

  return {
    isHovered,
    isLoading,
    kills: filteredKills,
    systemNameMap,
    handleMouseEnter,
    handleMouseLeave,
  };
}
