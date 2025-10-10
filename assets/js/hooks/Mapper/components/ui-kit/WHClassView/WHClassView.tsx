import classes from './WHClassView.module.scss';
import clsx from 'clsx';
import { InfoDrawer } from '@/hooks/Mapper/components/ui-kit/InfoDrawer';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { WORMHOLE_CLASS_STYLES, WORMHOLES_ADDITIONAL_INFO } from '@/hooks/Mapper/components/map/constants.ts';
import { useMemo } from 'react';
import { TooltipPosition, WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit';

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

  const content = (
    <div
      className={clsx(classes.WHClassViewContent, { [classes.NoOffset]: noOffset }, 'wh-name select-none cursor-help')}
    >
      {!hideWhClassName && <span className={clsx({ [whClassStyle]: highlightName })}>{whClassName}</span>}
      {!hideWhClass && whClass && (
        <span className={clsx(classes.WHClassName, whClassStyle, classNameWh)}>
          {useShortTitle ? whClass.shortTitle : whClass.shortName}
        </span>
      )}
    </div>
  );

  if (hideTooltip) {
    return <div className={clsx(classes.WHClassViewRoot, className)}>{content}</div>;
  }

  return (
    <div className={clsx(classes.WHClassViewRoot, className)}>
      <WdTooltipWrapper
        position={TooltipPosition.bottom}
        content={
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
        }
      >
        {content}
      </WdTooltipWrapper>
    </div>
  );
};
