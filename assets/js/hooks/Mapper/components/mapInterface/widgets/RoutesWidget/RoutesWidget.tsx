import { Widget } from '@/hooks/Mapper/components/mapInterface/components';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import {
  LayoutEventBlocker,
  SystemViewStandalone,
  TooltipPosition,
  WdCheckbox,
  WdImgButton,
} from '@/hooks/Mapper/components/ui-kit';
import { useLoadSystemStatic } from '@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic.ts';
import { MouseEvent, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { getSystemById } from '@/hooks/Mapper/helpers/getSystemById.ts';
import classes from './RoutesWidget.module.scss';
import { useLoadRoutes } from './hooks';
import { RoutesList } from './RoutesList';
import clsx from 'clsx';
import { Route } from '@/hooks/Mapper/types/routes.ts';
import { PrimeIcons } from 'primereact/api';
import { RoutesSettingsDialog } from './RoutesSettingsDialog';
import { RoutesProvider, useRouteProvider } from './RoutesProvider.tsx';
import { ContextMenuSystemInfo, useContextMenuSystemInfoHandlers } from '@/hooks/Mapper/components/contexts';

const sortByDist = (a: Route, b: Route) => {
  const distA = a.has_connection ? a.systems?.length || 0 : Infinity;
  const distB = b.has_connection ? b.systems?.length || 0 : Infinity;

  return distA - distB;
};

export const RoutesWidgetContent = () => {
  const {
    data: { selectedSystems, hubs = [], systems, routes },
    mapRef,
    outCommand,
  } = useMapRootState();

  const [systemId] = selectedSystems;

  const { loading } = useLoadRoutes();

  const { systems: systemStatics, loadSystems } = useLoadSystemStatic({ systems: hubs ?? [] });
  const { open, ...systemCtxProps } = useContextMenuSystemInfoHandlers({
    outCommand,
    hubs,
    mapRef,
  });

  const preparedHubs = useMemo(() => {
    return hubs.map(x => {
      const sys = getSystemById(systems, x.toString());

      return { ...systemStatics.get(parseInt(x))!, ...(sys && { customName: sys.name ?? '' }) };
    });
  }, [hubs, systems, systemStatics]);

  const preparedRoutes = useMemo(() => {
    return (
      routes?.routes
        .sort(sortByDist)
        .filter(x => x.destination.toString() !== systemId)
        .map(route => ({
          ...route,
          mapped_systems:
            route.systems?.map(solar_system_id =>
              routes?.systems_static_data.find(
                system_static_data => system_static_data.solar_system_id === solar_system_id,
              ),
            ) ?? [],
        })) ?? []
    );
  }, [routes?.routes, routes?.systems_static_data, systemId]);

  const refData = useRef({ open, loadSystems });
  refData.current = { open, loadSystems };

  useEffect(() => {
    (async () => await refData.current.loadSystems(hubs))();
  }, [hubs]);

  const handleClick = useCallback((e: MouseEvent, systemId: string) => {
    refData.current.open(e, systemId);
  }, []);

  const handleContextMenu = useCallback(
    async (e: MouseEvent, systemId: string) => {
      await refData.current.loadSystems([systemId]);
      handleClick(e, systemId);
    },
    [handleClick],
  );

  if (loading) {
    return (
      <div className="w-full h-full flex justify-center items-center select-none text-center">Loading routes...</div>
    );
  }

  if (!systemId) {
    return (
      <div className="w-full h-full flex justify-center items-center select-none text-center text-stone-400/80 text-sm">
        System is not selected
      </div>
    );
  }

  if (hubs.length === 0) {
    return <div className="w-full h-full flex justify-center items-center select-none">Routes not set</div>;
  }

  return (
    <>
      {systemId !== undefined && routes && (
        <div className={clsx(classes.RoutesGrid, 'px-2 py-2')}>
          {preparedRoutes.map(route => {
            const sys = preparedHubs.find(x => x.solar_system_id === route.destination)!;

            return (
              <>
                <div className="flex gap-2 items-center">
                  <WdImgButton
                    className={clsx(PrimeIcons.BARS, classes.RemoveBtn)}
                    onClick={e => handleClick(e, route.destination.toString())}
                    tooltip={{ content: 'Click here to open system menu', position: TooltipPosition.top, offset: 10 }}
                  />

                  <SystemViewStandalone
                    key={route.destination}
                    className={clsx('select-none text-center cursor-context-menu')}
                    hideRegion
                    compact
                    {...sys}
                  />
                </div>
                <div className="text-right pl-1">{route.has_connection ? route.systems?.length ?? 2 : ''}</div>
                <div className="pl-2 pb-0.5">
                  <RoutesList data={route} onContextMenu={handleContextMenu} />
                </div>
              </>
            );
          })}
        </div>
      )}

      <ContextMenuSystemInfo hubs={hubs} systems={systems} systemStatics={systemStatics} {...systemCtxProps} />
    </>
  );
};

export const RoutesWidgetComp = () => {
  const [routeSettingsVisible, setRouteSettingsVisible] = useState(false);
  const { data, update } = useRouteProvider();

  const isSecure = data.path_type === 'secure';
  const handleSecureChange = useCallback(() => {
    update({
      ...data,
      path_type: data.path_type === 'secure' ? 'shortest' : 'secure',
    });
  }, [data, update]);

  return (
    <Widget
      label={
        <div className="flex justify-between items-center text-xs w-full">
          <span className="select-none">Routes</span>
          <LayoutEventBlocker className="flex items-center gap-2">
            <WdCheckbox
              size="xs"
              labelSide="left"
              label={'Show shortest'}
              value={!isSecure}
              onChange={handleSecureChange}
              classNameLabel={clsx('text-red-400')}
            />
            <WdImgButton className={PrimeIcons.SLIDERS_H} onClick={() => setRouteSettingsVisible(true)} />
          </LayoutEventBlocker>
        </div>
      }
    >
      <RoutesWidgetContent />
      <RoutesSettingsDialog visible={routeSettingsVisible} setVisible={setRouteSettingsVisible} />
    </Widget>
  );
};

export const RoutesWidget = () => {
  return (
    <RoutesProvider>
      <RoutesWidgetComp />
    </RoutesProvider>
  );
};
