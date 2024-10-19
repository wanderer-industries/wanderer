import classes from './RoutesList.module.scss';
import { Route, SystemStaticInfoShort } from '@/hooks/Mapper/types/routes.ts';
import clsx from 'clsx';
import { SystemViewStandalone, WdTooltip, WdTooltipHandlers } from '@/hooks/Mapper/components/ui-kit';
import { getBackgroundClass, getShapeClass } from '@/hooks/Mapper/components/map/helpers';
import { MouseEvent, useCallback, useRef, useState } from 'react';
import { Commands } from '@/hooks/Mapper/types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

export type RouteSystemProps = {
  destination: number;
  onClick?(systemId: number): void;
  onMouseEnter?(systemId: number): void;
  onMouseLeave?(): void;
  onContextMenu?(e: MouseEvent, systemId: string): void;
  faded?: boolean;
} & SystemStaticInfoShort;

export const RouteSystem = ({
  system_class,
  security,
  solar_system_id,
  class_title,
  triglavian_invasion_status,
  solar_system_name,
  // destination,
  region_name,
  faded,
  onClick,
  onMouseEnter,
  onMouseLeave,
  onContextMenu,
}: RouteSystemProps) => {
  const tooltipRef = useRef<WdTooltipHandlers>(null);

  const handleContext = useCallback(
    (e: MouseEvent) => {
      e.preventDefault();
      e.stopPropagation();
      onContextMenu?.(e, solar_system_id.toString());
    },
    [onContextMenu, solar_system_id],
  );

  return (
    <>
      <WdTooltip
        ref={tooltipRef}
        // targetSelector={`.tooltip-route-sys_${destination}_${solar_system_id}`}
        content={() => (
          <SystemViewStandalone
            security={security}
            system_class={system_class}
            class_title={class_title}
            solar_system_name={solar_system_name}
            region_name={region_name}
            solar_system_id={solar_system_id}
          />
        )}
      />
      <div
        onMouseEnter={e => {
          tooltipRef.current?.show(e);
          onMouseEnter?.(solar_system_id);
        }}
        onMouseLeave={e => {
          tooltipRef.current?.hide(e);
          onMouseLeave?.();
        }}
        onContextMenu={handleContext}
        onClick={() => onClick?.(solar_system_id)}
        className={clsx(
          classes.RouteSystem,
          // `tooltip-route-sys_${destination}_${solar_system_id}`,
          getBackgroundClass(system_class, security),
          getShapeClass(system_class, triglavian_invasion_status),
          { [classes.Faded]: faded },
        )}
      ></div>
    </>
  );
};

export interface RoutesListProps {
  onContextMenu?(e: MouseEvent, systemId: string): void;
  data: Route;
}

export const RoutesList = ({ data, onContextMenu }: RoutesListProps) => {
  const [selected, setSelected] = useState<number | null>(null);
  const { mapRef } = useMapRootState();

  const handleClick = useCallback(
    (systemId: number) => mapRef.current?.command(Commands.centerSystem, systemId.toString()),
    [mapRef],
  );

  if (!data.has_connection) {
    return <div className="text-stone-400">No connection</div>;
  }

  return (
    <>
      <div className={classes.RoutesListRoot}>
        {data.mapped_systems?.filter(Boolean).map(x => {
          if (!x) {
            return null;
          }
          return (
            <RouteSystem
              key={x.solar_system_id}
              faded={selected !== null && selected !== x?.solar_system_id}
              destination={data.destination}
              {...x}
              onMouseEnter={systemId => {
                setSelected(systemId);
              }}
              onMouseLeave={() => {
                setSelected(null);
              }}
              onContextMenu={onContextMenu}
              onClick={handleClick}
            />
          );
        })}
      </div>
    </>
  );
};
