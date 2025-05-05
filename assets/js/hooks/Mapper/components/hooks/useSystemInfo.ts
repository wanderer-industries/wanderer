import { getSystemById } from '@/hooks/Mapper/helpers';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useMemo } from 'react';
import { getSystemStaticInfo } from '../../mapRootProvider/hooks/useLoadSystemStatic';

interface UseSystemInfoProps {
  systemId: string;
}

export const useSystemInfo = ({ systemId }: UseSystemInfoProps) => {
  const {
    data: { systems, connections },
  } = useMapRootState();

  return useMemo(() => {
    const staticInfo = getSystemStaticInfo(parseInt(systemId));
    const dynamicInfo = getSystemById(systems, systemId);

    if (!staticInfo || !dynamicInfo) {
      return { dynamicInfo, staticInfo, leadsTo: [] };
    }

    const leadsTo = connections
      .filter(x => [x.source, x.target].includes(systemId))
      .map(x => [x.source, x.target])
      .flat()
      .filter(x => x !== systemId);

    return { dynamicInfo, staticInfo, leadsTo };
  }, [systemId, systems, connections]);
};
