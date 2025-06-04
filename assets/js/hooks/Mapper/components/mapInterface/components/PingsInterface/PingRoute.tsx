import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useMemo } from 'react';
import { RoutesList } from '@/hooks/Mapper/components/mapInterface/widgets/RoutesWidget/RoutesList';

export const PingRoute = () => {
  const {
    data: { routes, pings, loadingPublicRoutes },
  } = useMapRootState();

  const route = useMemo(() => {
    const [ping] = pings;
    if (!ping) {
      return null;
    }

    return routes?.routes.find(x => ping.solar_system_id === x.destination.toString()) ?? null;
  }, [routes, pings]);

  const preparedRoute = useMemo(() => {
    if (!route) {
      return null;
    }

    return {
      ...route,
      mapped_systems:
        route.systems?.map(solar_system_id =>
          routes?.systems_static_data.find(
            system_static_data => system_static_data.solar_system_id === solar_system_id,
          ),
        ) ?? [],
    };
  }, [route, routes?.systems_static_data]);

  if (loadingPublicRoutes) {
    return <span className="m-0 text-[12px]">Loading...</span>;
  }

  if (!preparedRoute || preparedRoute.origin === preparedRoute.destination) {
    return null;
  }

  return (
    <div className="m-0 flex gap-2 items-center text-[12px]">
      {preparedRoute.has_connection && <div className="text-[12px]">{preparedRoute.systems?.length ?? 2}</div>}
      <RoutesList data={preparedRoute} />
    </div>
  );
};
