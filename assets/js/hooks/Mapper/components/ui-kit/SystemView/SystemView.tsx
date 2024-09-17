import { WithClassName } from '@/hooks/Mapper/types/common.ts';
import { SystemViewStandalone } from '@/hooks/Mapper/components/ui-kit';
import { useLoadSystemStatic } from '@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic.ts';
import { useMemo } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

export type SystemViewProps = {
  systemId: string;
  hideRegion?: boolean;
  useSystemsCache?: boolean;
  showCustomName?: boolean;
} & WithClassName;

export const SystemView = ({ systemId, hideRegion, className, showCustomName }: SystemViewProps) => {
  const memSystems = useMemo(() => [systemId], [systemId]);
  const { systems, loading } = useLoadSystemStatic({ systems: memSystems });

  const {
    data: { systems: mapSystems },
  } = useMapRootState();

  const systemInfo = useMemo(() => {
    return systems.get(parseInt(systemId));
    // eslint-disable-next-line
  }, [systemId, systems, loading]);

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
    return <SystemViewStandalone hideRegion={hideRegion} className={className} {...systemInfo} />;
  }

  return (
    <div>
      <SystemViewStandalone hideRegion={hideRegion} className={className} {...systemInfo} />
      <span>{systemInfo.solar_system_name}</span>
    </div>
  );
};
