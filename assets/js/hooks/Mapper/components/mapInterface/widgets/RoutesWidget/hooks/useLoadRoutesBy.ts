import { useCallback, useEffect, useRef, useState } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { RoutesType } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { LoadRoutesCommand } from '@/hooks/Mapper/components/mapInterface/widgets/RoutesWidget/types.ts';
import { RoutesList } from '@/hooks/Mapper/types/routes.ts';
import { flattenValues } from '@/hooks/Mapper/utils/flattenValues.ts';
import { useMapEventListener } from '@/hooks/Mapper/events';
import { Commands } from '@/hooks/Mapper/types';

function usePrevious<T>(value: T): T | undefined {
  const ref = useRef<T>();

  useEffect(() => {
    ref.current = value;
  }, [value]);

  return ref.current;
}

type UseLoadRoutesByProps = {
  loadRoutesCommand: LoadRoutesCommand;
  routesList: RoutesList | undefined;
  data: RoutesType;
  deps?: unknown[];
};

export const useLoadRoutesBy = ({
  data: routesSettings,
  loadRoutesCommand,
  routesList,
  deps = [],
}: UseLoadRoutesByProps) => {
  const [loading, setLoading] = useState(false);

  const {
    data: { selectedSystems },
  } = useMapRootState();

  const prevSys = usePrevious(selectedSystems);
  const ref = useRef({ prevSys, selectedSystems });
  ref.current = { prevSys, selectedSystems };

  const loadRoutes = useCallback(
    (systemId: string, settings: RoutesType) => {
      loadRoutesCommand(systemId, settings);
      setLoading(true);
    },
    [loadRoutesCommand],
  );

  useMapEventListener(event => {
    if (event.name === Commands.routesListBy) {
      setLoading(false);
    }
  });

  useEffect(() => {
    setLoading(false);
  }, [routesList]);

  useEffect(() => {
    if (selectedSystems.length !== 1) {
      return;
    }

    const [systemId] = selectedSystems;
    loadRoutes(systemId, routesSettings);
  }, [loadRoutes, selectedSystems, ...flattenValues(routesSettings), ...deps]);

  return { loading, loadRoutes, setLoading };
};
