import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useMemo } from 'react';
import { getSystemById } from '@/hooks/Mapper/helpers';
import { useLoadSystemStatic } from '@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic.ts';

interface UseSystemInfoProps {
  systemId: string;
}

export const useSystemInfo = ({ systemId }: UseSystemInfoProps) => {
  const {
    data: { systems, connections },
  } = useMapRootState();

  const { systems: systemStatics } = useLoadSystemStatic({ systems: [systemId] });

  // eslint-disable-next-line no-console
  console.log('JOipP', `systemStatics`, systemStatics);

  return useMemo(() => {
    const staticInfo = systemStatics.get(parseInt(systemId));
    const dynamicInfo = getSystemById(systems, systemId);

    if (!staticInfo || !dynamicInfo) {
      throw new Error(`Error on getting system ${systemId}`);
    }

    const leadsTo = connections
      .filter(x => [x.source, x.target].includes(systemId))
      .map(x => [x.source, x.target])
      .flat()
      .filter(x => x !== systemId);

    return { dynamicInfo, staticInfo, leadsTo };
  }, [systemStatics, systemId, systems, connections]);
};
