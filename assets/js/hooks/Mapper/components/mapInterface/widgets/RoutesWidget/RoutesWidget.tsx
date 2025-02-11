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
import useMaxWidth from '@/hooks/Mapper/hooks/useMaxWidth.ts';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import {
  AddSystemDialog,
  SearchOnSubmitCallback,
} from '@/hooks/Mapper/components/mapInterface/components/AddSystemDialog';
import { OutCommand } from '@/hooks/Mapper/types';

const sortByDist = (a: Route, b: Route) => {
  const distA = a.has_connection ? a.systems?.length || 0 : Infinity;
  const distB = b.has_connection ? b.systems?.length || 0 : Infinity;

  return distA - distB;
};

export const RoutesWidgetContent = () => {
  const {
    data: { selectedSystems, hubs = [], systems, routes },
    outCommand,
  } = useMapRootState();

  const [systemId] = selectedSystems;

  const { loading } = useLoadRoutes();

  const { systems: systemStatics, loadSystems, lastUpdateKey } = useLoadSystemStatic({ systems: hubs ?? [] });
  const { open, ...systemCtxProps } = useContextMenuSystemInfoHandlers({
    outCommand,
    hubs,
  });

  const preparedHubs = useMemo(() => {
    return hubs.map(x => {
      const sys = getSystemById(systems, x.toString());

      return { ...systemStatics.get(parseInt(x))!, ...(sys && { customName: sys.name ?? '' }) };
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [hubs, systems, systemStatics, lastUpdateKey]);

  const preparedRoutes: Route[] = useMemo(() => {
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

  const refData = useRef({ open, loadSystems, preparedRoutes });
  refData.current = { open, loadSystems, preparedRoutes };

  useEffect(() => {
    (async () => await refData.current.loadSystems(hubs))();
  }, [hubs]);

  const handleClick = useCallback((e: MouseEvent, systemId: string) => {
    const route = refData.current.preparedRoutes.find(x => x.destination.toString() === systemId);

    refData.current.open(e, systemId, route?.mapped_systems ?? []);
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

            // TODO do not delte this console log
            // eslint-disable-next-line no-console
            // console.log('JOipP', `Check sys [${route.destination}]:`, sys);

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

      <ContextMenuSystemInfo
        hubs={hubs}
        routes={preparedRoutes}
        systems={systems}
        systemStatics={systemStatics}
        systemIdFrom={systemId}
        {...systemCtxProps}
      />
    </>
  );
};

export const RoutesWidgetComp = () => {
  const [routeSettingsVisible, setRouteSettingsVisible] = useState(false);
  const { data, update } = useRouteProvider();
  const {
    data: { hubs = [] },
    outCommand,
  } = useMapRootState();

  const preparedHubs = useMemo(() => hubs.map(x => parseInt(x)), [hubs]);

  const isSecure = data.path_type === 'secure';
  const handleSecureChange = useCallback(() => {
    update({
      ...data,
      path_type: data.path_type === 'secure' ? 'shortest' : 'secure',
    });
  }, [data, update]);

  const ref = useRef<HTMLDivElement>(null);
  const compact = useMaxWidth(ref, 170);
  const [openAddSystem, setOpenAddSystem] = useState<boolean>(false);

  const onAddSystem = useCallback(() => setOpenAddSystem(true), []);

  const handleSubmitAddSystem: SearchOnSubmitCallback = useCallback(
    async item => {
      if (preparedHubs.includes(item.value)) {
        return;
      }

      await outCommand({
        type: OutCommand.addHub,
        data: { system_id: item.value },
      });
    },
    [hubs, outCommand],
  );

  return (
    <Widget
      label={
        <div className="flex justify-between items-center text-xs w-full" ref={ref}>
          <span className="select-none">Routes</span>
          <LayoutEventBlocker className="flex items-center gap-2">
            <WdImgButton
              className={PrimeIcons.PLUS_CIRCLE}
              onClick={onAddSystem}
              tooltip={{
                content: 'Click here to add new system to routes',
              }}
            />

            <WdTooltipWrapper content="Show shortest route" position={TooltipPosition.top}>
              <WdCheckbox
                size="xs"
                labelSide="left"
                label={compact ? '' : 'Show shortest'}
                value={!isSecure}
                onChange={handleSecureChange}
                classNameLabel="text-red-400 whitespace-nowrap"
              />
            </WdTooltipWrapper>
            <WdImgButton
              className={PrimeIcons.SLIDERS_H}
              onClick={() => setRouteSettingsVisible(true)}
              tooltip={{
                content: 'Click here to open Routes settings',
              }}
            />
          </LayoutEventBlocker>
        </div>
      }
    >
      <RoutesWidgetContent />
      <RoutesSettingsDialog visible={routeSettingsVisible} setVisible={setRouteSettingsVisible} />

      <AddSystemDialog
        title="Add system to routes"
        visible={openAddSystem}
        setVisible={() => setOpenAddSystem(false)}
        onSubmit={handleSubmitAddSystem}
      />
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
