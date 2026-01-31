import { useCallback, useMemo, useRef, useState } from 'react';
import { RoutesWidget } from '@/hooks/Mapper/components/mapInterface/widgets';
import { LoadRoutesCommand } from '@/hooks/Mapper/components/mapInterface/widgets/RoutesWidget/types.ts';
import { useLoadRoutesBy } from '@/hooks/Mapper/components/mapInterface/widgets/RoutesWidget/hooks';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { OutCommand } from '@/hooks/Mapper/types';
import { Dropdown } from 'primereact/dropdown';
import { SelectItemOptionsType } from 'primereact/selectitem';
import useMaxWidth from '@/hooks/Mapper/hooks/useMaxWidth.ts';
import clsx from 'clsx';

export type RoutesByType = 'blueLoot' | 'redLoot';
export type RoutesBySecurityType = 'both' | 'low' | 'high';

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
];
const ROUTES_BY_SECURITY_OPTIONS = [
  { label: 'All', value: 'both' },
  { label: 'High', value: 'high' },
  { label: 'Low', value: 'low' },
];

export const WRoutesBy = ({ type = 'blueLoot', title = 'Routes By' }: WRoutesByProps) => {
  const {
    outCommand,
    storedSettings: { settingsRoutes, settingsRoutesUpdate },
    data,
  } = useMapRootState();

  const [criteriaType, setCriteriaType] = useState<RoutesByType>(type);
  const [securityType, setSecurityType] = useState<RoutesBySecurityType>('both');
  const routesListBy = data.routesListBy;

  const loadRoutesCommand: LoadRoutesCommand = useCallback(
    async (systemId, routesSettings) => {
      await outCommand({
        type: OutCommand.getRoutesBy,
        data: {
          system_id: systemId,
          type: criteriaType,
          securityType: securityType || 'both',
          routes_settings: routesSettings,
        },
      });
    },
    [outCommand, criteriaType, securityType],
  );

  const hubs = useMemo(() => routesListBy?.routes?.map(route => route.destination.toString()) ?? [], [routesListBy]);

  const { loading: internalLoading } = useLoadRoutesBy({
    data: settingsRoutes,
    loadRoutesCommand,
    routesList: routesListBy,
    deps: [criteriaType, securityType],
  });

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
                onChange={e => setSecurityType(e.value)}
                className="w-[90px] [&_span]:!text-[12px]"
              />
            )}
            <Dropdown
              value={criteriaType}
              itemTemplate={e => {
                return (
                  <div className="flex items-center gap-2">
                    <img src={e.icon} height="18" width="18"></img>
                    <span className="text-[12px]">{e.label}</span>
                  </div>
                );
              }}
              valueTemplate={e => {
                if (compactMiddle) {
                  return (
                    <div className="flex items-center gap-2 min-w-[50px]">
                      <img src={e.icon} height="18" width="18"></img>
                    </div>
                  );
                }

                return (
                  <div className="flex items-center gap-2">
                    <img src={e.icon} height="18" width="18"></img>
                    <span className="text-[12px]">{e.label}</span>
                  </div>
                );
              }}
              options={ROUTES_BY_OPTIONS}
              onChange={e => setCriteriaType(e.value)}
              className={clsx({
                ['w-[130px]']: !compactMiddle,
                ['w-[65px]']: compactMiddle,
              })}
            />
          </div>
        </div>
      )}
      data={settingsRoutes}
      update={settingsRoutesUpdate}
      hubs={hubs}
      routesList={routesListBy}
      loading={internalLoading}
    />
  );
};
