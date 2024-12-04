import classes from './WHClassView.module.scss';
import { Tooltip } from 'primereact/tooltip';
import clsx from 'clsx';
import { InfoDrawer } from '@/hooks/Mapper/components/ui-kit/InfoDrawer';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { WORMHOLE_CLASS_STYLES, WORMHOLES_ADDITIONAL_INFO } from '@/hooks/Mapper/components/map/constants.ts';
import { useMemo } from 'react';

const prepareMass = (mass: number) => {
  if (mass === 0) {
    return `0 t`;
  }

  return `${(mass / 1000).toLocaleString('de-DE')} t`;
};

export interface WHClassViewProps {
  whClassName: string;
  noOffset?: boolean;
  useShortTitle?: boolean;
  hideTooltip?: boolean;
  hideWhClass?: boolean;
  hideWhClassName?: boolean;
  highlightName?: boolean;
  className?: string;
  classNameWh?: string;
}

export const WHClassView = ({
  whClassName,
  noOffset,
  useShortTitle,
  hideTooltip,
  hideWhClass,
  hideWhClassName,
  highlightName,
  className,
  classNameWh,
}: WHClassViewProps) => {
  const {
    data: { wormholesData },
  } = useMapRootState();

  const whData = useMemo(() => wormholesData[whClassName], [whClassName, wormholesData]);
  const whClass = useMemo(() => WORMHOLES_ADDITIONAL_INFO[whData.dest], [whData.dest]);
  const whClassStyle = WORMHOLE_CLASS_STYLES[whClass?.wormholeClassID] ?? '';

  const uid = useMemo(() => new Date().getTime().toString(), []);

  return (
    <div className={clsx(classes.WHClassViewRoot, className)}>
      {!hideTooltip && (
        <Tooltip
          target={`.wh-name${whClassName}${uid}`}
          position="right"
          mouseTrack
          mouseTrackLeft={20}
          mouseTrackTop={30}
          className="border border-green-300 rounded border-opacity-10 bg-stone-900 bg-opacity-90 "
        >
          <div className="flex gap-3">
            <div className="flex flex-col gap-1">
              <InfoDrawer title="Total mass">{prepareMass(whData.total_mass)}</InfoDrawer>
              <InfoDrawer title="Jump mass">{prepareMass(whData.max_mass_per_jump)}</InfoDrawer>
            </div>
            <div className="flex flex-col gap-1">
              <InfoDrawer title="Lifetime">{whData.lifetime}h</InfoDrawer>
              <InfoDrawer title="Mass regen">{prepareMass(whData.mass_regen)}</InfoDrawer>
            </div>
          </div>
        </Tooltip>
      )}

      <div
        className={clsx(
          classes.WHClassViewContent,
          { [classes.NoOffset]: noOffset },
          'wh-name select-none cursor-help',
          `wh-name${whClassName}${uid}`,
        )}
      >
        {!hideWhClassName && <span className={clsx({ [whClassStyle]: highlightName })}>{whClassName}</span>}
        {!hideWhClass && whClass && (
          <span className={clsx(classes.WHClassName, whClassStyle, classNameWh)}>
            {useShortTitle ? whClass.shortTitle : whClass.shortName}
          </span>
        )}
      </div>
    </div>
  );
};
