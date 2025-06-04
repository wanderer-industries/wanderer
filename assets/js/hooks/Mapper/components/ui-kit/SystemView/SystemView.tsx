import { SystemViewStandalone, SystemViewStandaloneProps } from '@/hooks/Mapper/components/ui-kit';
import { useLoadSystemStatic } from '@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic.ts';
import { useMemo } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { SolarSystemStaticInfoRaw } from '@/hooks/Mapper/types';

export type SystemViewProps = {
  systemId: string;
  systemInfo?: SolarSystemStaticInfoRaw;
  useSystemsCache?: boolean;
  showCustomName?: boolean;
} & Pick<SystemViewStandaloneProps, 'className' | 'compact' | 'hideRegion'>;

export const SystemView = ({ systemId, systemInfo: customSystemInfo, showCustomName, ...rest }: SystemViewProps) => {
  const memSystems = useMemo(() => [systemId], [systemId]);
  const { systems, loading } = useLoadSystemStatic({ systems: memSystems });

  const {
    data: { systems: mapSystems },
  } = useMapRootState();

  const systemInfo = useMemo(() => {
    if (!systemId) {
      return customSystemInfo;
    }
    return systems.get(parseInt(systemId));
    // eslint-disable-next-line
  }, [customSystemInfo, systemId, systems, loading]);

  const mapSystemInfo = useMemo(() => {
    if (!showCustomName) {
      return null;
    }
    return mapSystems.find(x => x.id === systemId);
  }, [showCustomName, systemId, mapSystems]);

  if (!systemInfo) {
    return null;
  }

  if (!mapSystemInfo) {
    return <SystemViewStandalone {...rest} {...systemInfo} />;
  }

  return <SystemViewStandalone customName={mapSystemInfo.name ?? undefined} {...rest} {...systemInfo} />;
};
