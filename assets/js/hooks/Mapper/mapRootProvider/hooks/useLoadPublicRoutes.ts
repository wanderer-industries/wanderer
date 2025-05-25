import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { LoadRoutesCommand } from '@/hooks/Mapper/components/mapInterface/widgets/RoutesWidget/types.ts';
import { useCallback, useEffect } from 'react';
import { Commands, OutCommand } from '@/hooks/Mapper/types';
import { useLoadRoutes } from '@/hooks/Mapper/components/mapInterface/widgets/RoutesWidget/hooks';
import { useMapEventListener } from '@/hooks/Mapper/events';

export const useLoadPublicRoutes = () => {
  const {
    outCommand,
    storedSettings: { settingsRoutes },
    data: { hubs, routes, pings },
    update,
  } = useMapRootState();

  const loadRoutesCommand: LoadRoutesCommand = useCallback(
    async (systemId, routesSettings) => {
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

  const { loading, setLoading } = useLoadRoutes({
    data: settingsRoutes,
    hubs: hubs,
    loadRoutesCommand,
    routesList: routes,
    deps: [pings],
  });

  useEffect(() => {
    update({ loadingPublicRoutes: loading });
  }, [loading, update]);

  useMapEventListener(event => {
    if (event.name === Commands.routes) {
      setLoading(false);
    }
  });
};
