import { useCallback, useEffect, useRef, useState } from 'react';
import { OutCommand } from '@/hooks/Mapper/types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import {
  RoutesType,
  useRouteProvider,
} from '@/hooks/Mapper/components/mapInterface/widgets/RoutesWidget/RoutesProvider.tsx';

function usePrevious<T>(value: T): T | undefined {
  const ref = useRef<T>();

  useEffect(() => {
    ref.current = value;
  }, [value]);

  return ref.current;
}

export const useLoadRoutes = () => {
  const [loading, setLoading] = useState(false);
  const { data: routesSettings } = useRouteProvider();

  const {
    outCommand,
    data: { selectedSystems, hubs, systems, connections },
  } = useMapRootState();

  const prevSys = usePrevious(systems);
  const ref = useRef({ prevSys, selectedSystems });
  ref.current = { prevSys, selectedSystems };

  const loadRoutes = useCallback(
    (systemId: string, routesSettings: RoutesType) => {
      outCommand({
        type: OutCommand.getRoutes,
        data: {
          system_id: systemId,
          routes_settings: routesSettings,
        },
      });
    },
    [outCommand],
  );

  useEffect(() => {
    if (selectedSystems.length !== 1) {
      return;
    }

    const [systemId] = selectedSystems;
    loadRoutes(systemId, routesSettings);
  }, [
    loadRoutes,
    selectedSystems,
    systems?.length,
    connections,
    hubs,
    routesSettings,
    ...Object.keys(routesSettings)
      .sort()
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-expect-error
      .map(x => routesSettings[x]),
  ]);

  return { loading, loadRoutes };
};
