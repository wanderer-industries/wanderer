import { getSystemClassStyles } from '@/hooks/Mapper/components/map/helpers';
import { isWormholeSpace } from '@/hooks/Mapper/components/map/helpers/isWormholeSpace.ts';
import classes from './SystemViewStandalone.module.scss';
import clsx from 'clsx';
import { WithClassName } from '@/hooks/Mapper/types/common.ts';
import { SolarSystemStaticInfoRaw } from '@/hooks/Mapper/types';
import { HTMLProps, MouseEvent, useCallback } from 'react';

export type SystemViewStandaloneStatic = Pick<
  SolarSystemStaticInfoRaw,
  'class_title' | 'system_class' | 'solar_system_name' | 'region_name' | 'security' | 'solar_system_id'
>;

export type SystemViewStandaloneProps = {
  hideRegion?: boolean;
  customName?: string;
  nameClassName?: string;
  compact?: boolean;
  onContextMenu?(e: MouseEvent, systemId: string): void;
} & WithClassName &
  Omit<SystemViewStandaloneStatic, 'region_name'> &
  Partial<Pick<SystemViewStandaloneStatic, 'region_name'>> &
  Omit<HTMLProps<HTMLDivElement>, 'onContextMenu'>;

export const SystemViewStandalone = ({
  className,
  nameClassName,
  hideRegion,
  customName,
  class_title,
  system_class,
  solar_system_name,
  region_name,
  security,
  compact,
  solar_system_id,
  onContextMenu,

  ...props
}: SystemViewStandaloneProps) => {
  const classTitleColor = getSystemClassStyles({ systemClass: system_class, security });
  const isWH = isWormholeSpace(system_class);
  1;

  const handleClick = useCallback(
    (e: MouseEvent) => {
      e.preventDefault();
      e.stopPropagation();
      onContextMenu?.(e, solar_system_id.toString());
    },
    [onContextMenu, solar_system_id],
  );

  return (
    <div
      {...props}
      onContextMenu={handleClick}
      className={clsx(classes.SystemViewRoot, 'flex gap-1 text-gray-400', className)}
    >
      <span className={clsx(classTitleColor)}>{class_title}</span>
      <span
        className={clsx(
          'text-gray-200 whitespace-nowrap',
          {
            ['overflow-hidden text-ellipsis']: compact,
            [classes.CompactName]: compact,
          },
          nameClassName,
        )}
      >
        {customName ?? solar_system_name}
      </span>
      {!hideRegion && !isWH && <span className="whitespace-nowrap">{region_name}</span>}
    </div>
  );
};
