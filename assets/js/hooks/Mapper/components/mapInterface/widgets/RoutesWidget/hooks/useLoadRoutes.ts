import { useCallback, useEffect, useRef, useState } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { RoutesType } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { LoadRoutesCommand } from '@/hooks/Mapper/components/mapInterface/widgets/RoutesWidget/types.ts';
import { RoutesList } from '@/hooks/Mapper/types/routes.ts';
import { flattenValues } from '@/hooks/Mapper/utils/flattenValues.ts';

function usePrevious<T>(value: T): T | undefined {
  const ref = useRef<T>();

  useEffect(() => {
    ref.current = value;
  }, [value]);

  return ref.current;
}

type UseLoadRoutesProps = {
  loadRoutesCommand: LoadRoutesCommand;
  hubs: string[];
  routesList: RoutesList | undefined;
  data: RoutesType;
  deps?: unknown[];
};

export const useLoadRoutes = ({
  data: routesSettings,
  loadRoutesCommand,
  hubs,
  routesList,
  deps = [],
}: UseLoadRoutesProps) => {
  const [loading, setLoading] = useState(false);

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
    // we need make it flat recursively
    ...flattenValues(routesSettings),
    ...deps,
  ]);

  return { loading, loadRoutes, setLoading };
};
