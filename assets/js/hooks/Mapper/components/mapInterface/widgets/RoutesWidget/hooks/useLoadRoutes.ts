import { useCallback, useEffect, useRef } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useRouteProvider } from '@/hooks/Mapper/components/mapInterface/widgets/RoutesWidget/RoutesProvider.tsx';
import { RoutesType } from '@/hooks/Mapper/mapRootProvider/types.ts';

function usePrevious<T>(value: T): T | undefined {
  const ref = useRef<T>();

  useEffect(() => {
    ref.current = value;
  }, [value]);

  return ref.current;
}

export const useLoadRoutes = () => {
  const { data: routesSettings, loadRoutesCommand, hubs, routesList, loading, setLoading } = useRouteProvider();

  const {
    data: { selectedSystems, systems, connections },
  } = useMapRootState();

  const prevSys = usePrevious(systems);
  const ref = useRef({ prevSys, selectedSystems });
  ref.current = { prevSys, selectedSystems };

  const loadRoutes = useCallback(
    (systemId: string, routesSettings: RoutesType) => {
      loadRoutesCommand(systemId, routesSettings);
      setLoading(true);
    },
    [loadRoutesCommand],
  );

  useEffect(() => {
    setLoading(false);
  }, [routesList]);

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
