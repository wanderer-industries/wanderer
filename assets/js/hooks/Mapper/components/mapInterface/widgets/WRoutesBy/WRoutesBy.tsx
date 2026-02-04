import { useCallback, useMemo, useRef } from 'react';
import { RoutesWidget } from '@/hooks/Mapper/components/mapInterface/widgets';
import { LoadRoutesCommand } from '@/hooks/Mapper/components/mapInterface/widgets/RoutesWidget/types.ts';
import { useLoadRoutesBy } from '@/hooks/Mapper/components/mapInterface/widgets/RoutesWidget/hooks';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { OutCommand } from '@/hooks/Mapper/types';
import { Dropdown } from 'primereact/dropdown';
import { SelectItemOptionsType } from 'primereact/selectitem';
import useMaxWidth from '@/hooks/Mapper/hooks/useMaxWidth.ts';
import clsx from 'clsx';
import { RoutesByCategoryType, RoutesByScopeType, RoutesType } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { DEFAULT_ROUTES_SETTINGS } from '@/hooks/Mapper/mapRootProvider/constants.ts';

export type RoutesByType = RoutesByCategoryType;
export type RoutesBySecurityType = RoutesByScopeType;

type WRoutesByProps = {
  type?: RoutesByType;
  title?: string;
};

const ROUTES_BY_OPTIONS: SelectItemOptionsType = [
  {
    label: 'Blue Loot',
    value: 'blueLoot',
    icon: 'images/30747_64.png',
  },
  {
    label: 'Red Loot',
    value: 'redLoot',
    icon: 'images/89219_64.png',
  },
  {
    label: 'Thera',
    value: 'thera',
    icon: 'images/map.png',
  },
  {
    label: 'Turnur',
    value: 'turnur',
    icon: 'images/map.png',
  },
  {
    label: 'Security Office',
    value: 'so_cleaning',
    icon: 'images/concord-so.png',
  },
  {
    label: 'Trade Hubs',
    value: 'trade_hubs',
    icon: 'images/market.png',
  },
];
const ROUTES_BY_SECURITY_OPTIONS = [
  { label: 'All', value: 'ALL' },
  { label: 'High', value: 'HIGH' },
];

export const WRoutesBy = ({ type = 'blueLoot', title = 'Routes By' }: WRoutesByProps) => {
  const {
    outCommand,
    storedSettings: { settingsRoutesBy, settingsRoutesByUpdate },
    data,
  } = useMapRootState();

  const criteriaType = settingsRoutesBy.type ?? type;
  const securityType = settingsRoutesBy.scope ?? 'ALL';
  const routesSettings = settingsRoutesBy.routes ?? DEFAULT_ROUTES_SETTINGS;
  const routesListBy = data.routesListBy;

  const loadRoutesCommand: LoadRoutesCommand = useCallback(
    async (systemId, currentRoutesSettings) => {
      await outCommand({
        type: OutCommand.getRoutesBy,
        data: {
          system_id: systemId,
          type: criteriaType,
          securityType: securityType === 'HIGH' ? 'high' : 'both',
          routes_settings: currentRoutesSettings,
        },
      });
    },
    [outCommand, criteriaType, securityType],
  );

  const hubs = useMemo(() => routesListBy?.routes?.map(route => route.destination.toString()) ?? [], [routesListBy]);

  const { loading: internalLoading } = useLoadRoutesBy({
    data: routesSettings,
    loadRoutesCommand,
    routesList: routesListBy,
    deps: [criteriaType, securityType],
  });

  const updateRoutesSettings = useCallback(
    (next: Partial<RoutesType> | ((prev: RoutesType) => Partial<RoutesType>)) =>
      settingsRoutesByUpdate(prev => ({
        routes: {
          ...prev.routes,
          ...(typeof next === 'function' ? next(prev.routes) : next),
        },
      })),
    [settingsRoutesByUpdate],
  );

  const ref = useRef<HTMLDivElement>(null);

  const compactSmall = useMaxWidth(ref, 180);
  const compactMiddle = useMaxWidth(ref, 245);

  return (
    <RoutesWidget
      title={title}
      renderContent={(content /*, compact*/) => (
        <div className="h-full grid grid-rows-[1fr_auto]" ref={ref}>
          {content}
          <div className="flex items-center gap-2 justify-end mb-2 px-2 pt-2">
            {!compactSmall && (
              <Dropdown
                value={securityType}
                options={ROUTES_BY_SECURITY_OPTIONS}
                onChange={e => settingsRoutesByUpdate({ scope: e.value as RoutesBySecurityType })}
                className="w-[90px] [&_span]:!text-[12px]"
              />
            )}
            <Dropdown
              value={criteriaType}
              itemTemplate={e => (
                <div className="flex items-center gap-2">
                  {e.icon && <img src={e.icon} height="18" width="18" />}
                  <span className="text-[12px]">{e.label}</span>
                </div>
              )}
              valueTemplate={e => {
                if (!e) {
                  return null;
                }

                if (compactMiddle) {
                  return (
                    <div className="flex items-center gap-2 min-w-[50px]">
                      {e.icon ? <img src={e.icon} height="18" width="18" /> : <span>{e.label}</span>}
                    </div>
                  );
                }

                return (
                  <div className="flex items-center gap-2">
                    {e.icon && <img src={e.icon} height="18" width="18" />}
                    <span className="text-[12px]">{e.label}</span>
                  </div>
                );
              }}
              options={ROUTES_BY_OPTIONS}
              onChange={e => settingsRoutesByUpdate({ type: e.value as RoutesByType })}
              className={clsx({
                ['w-[130px]']: !compactMiddle,
                ['w-[65px]']: compactMiddle,
              })}
            />
          </div>
        </div>
      )}
      data={routesSettings}
      update={updateRoutesSettings}
      hubs={hubs}
      routesList={routesListBy}
      loading={internalLoading}
    />
  );
};
