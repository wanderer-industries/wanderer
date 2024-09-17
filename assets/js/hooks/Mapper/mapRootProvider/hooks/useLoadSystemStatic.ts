import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback, useEffect, useRef, useState } from 'react';
import { OutCommand, OutCommandHandler, SolarSystemStaticInfoRaw } from '@/hooks/Mapper/types';

type SystemStaticResult = {
  system_static_infos: SolarSystemStaticInfoRaw[];
};

// TODO maybe later we can store in Static data in provider
const cache = new Map<number, SolarSystemStaticInfoRaw>();

export const loadSystemStaticInfo = async (outCommand: OutCommandHandler, systems: number[]) => {
  const result = await outCommand({
    type: OutCommand.getSystemStaticInfos,
    data: {
      solar_system_ids: systems,
    },
  });

  return (result as SystemStaticResult).system_static_infos;
};

interface UseLoadSystemStaticProps {
  systems: (number | string)[];
}

export const useLoadSystemStatic = ({ systems }: UseLoadSystemStaticProps) => {
  const { outCommand } = useMapRootState();
  const [loading, setLoading] = useState(false);

  const ref = useRef({ outCommand });
  ref.current = { outCommand };

  const addSystemStatic = useCallback((static_info: SolarSystemStaticInfoRaw) => {
    cache.set(static_info.solar_system_id, static_info);
  }, []);

  const loadSystems = useCallback(async (systems: (number | string)[]) => {
    setLoading(true);
    const allSystems = systems.map(x => (typeof x == 'number' ? x : parseInt(x)));
    const toLoad = allSystems.filter(x => !cache.has(x));

    if (toLoad.length > 0) {
      const res = await loadSystemStaticInfo(ref.current.outCommand, toLoad);
      res.forEach(x => cache.set(x.solar_system_id, x));
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    loadSystems(systems);
    // eslint-disable-next-line
  }, [systems]);

  return { addSystemStatic, systems: cache, loading, loadSystems };
};
