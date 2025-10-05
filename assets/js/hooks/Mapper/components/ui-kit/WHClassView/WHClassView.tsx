import classes from './WHClassView.module.scss';
import clsx from 'clsx';
import { InfoDrawer } from '@/hooks/Mapper/components/ui-kit/InfoDrawer';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { WORMHOLE_CLASS_STYLES, WORMHOLES_ADDITIONAL_INFO } from '@/hooks/Mapper/components/map/constants.ts';
import { useMemo } from 'react';
import { WdTooltipWrapper, TooltipPosition } from '@/hooks/Mapper/components/ui-kit';

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
  showRigRow?: boolean;
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
  showRigRow = false,
}: WHClassViewProps) => {
  const {
    data: { wormholesData },
  } = useMapRootState();

  const whData = useMemo(() => wormholesData[whClassName], [whClassName, wormholesData]);
  const whClass = useMemo(() => WORMHOLES_ADDITIONAL_INFO[whData.dest], [whData.dest]);
  const whClassStyle = WORMHOLE_CLASS_STYLES[whClass?.wormholeClassID] ?? '';

  const tooltipContent = !hideTooltip ? (
    <>
      {showRigRow && (
        <div className="flex gap-3 mb-1">
          <div className="flex flex-col gap-1 basis-1/2 shrink-0">
            <InfoDrawer title="Signature">
              <span className="text-white">{whClassName}</span>
            </InfoDrawer>
          </div>
          <div className="flex flex-col gap-1 basis-1/2 shrink-0">
            <InfoDrawer title="Class">
              <span className={clsx(classes.WHClassName, whClassStyle, classNameWh, 'text-white')}>
                {useShortTitle ? whClass.shortTitle : whClass.shortName}
              </span>
            </InfoDrawer>
          </div>
        </div>
      )}

      <div className="flex gap-3">
        <div className="flex flex-col gap-1 basis-1/2 shrink-0">
          <InfoDrawer title="Total mass">
            <span className="text-white">{prepareMass(whData.total_mass)}</span>
          </InfoDrawer>
          <InfoDrawer title="Jump mass">
            <span className="text-white">{prepareMass(whData.max_mass_per_jump)}</span>
          </InfoDrawer>
        </div>
        <div className="flex flex-col gap-1 basis-1/2 shrink-0">
          <InfoDrawer title="Lifetime">
            <span className="text-white">{whData.lifetime}h</span>
          </InfoDrawer>
          <InfoDrawer title="Mass regen">
            <span className="text-white">{prepareMass(whData.mass_regen)}</span>
          </InfoDrawer>
        </div>
      </div>
    </>
  ) : undefined;

  return (
    <div className={clsx(classes.WHClassViewRoot, className)}>
      <WdTooltipWrapper
        content={tooltipContent}
        position={TooltipPosition.right}
        smallPaddings
        tooltipClassName="border border-green-300 rounded border-opacity-10 bg-stone-900 bg-opacity-75"
      >
        <div
          className={clsx(
            classes.WHClassViewContent,
            { [classes.NoOffset]: noOffset },
            'wh-name select-none cursor-help',
          )}
        >
          {!hideWhClassName && <span className={clsx({ [whClassStyle]: highlightName })}>{whClassName}</span>}
          {!hideWhClass && whClass && (
            <span className={clsx(classes.WHClassName, whClassStyle, classNameWh)}>
              {useShortTitle ? whClass.shortTitle : whClass.shortName}
            </span>
          )}
        </div>
      </WdTooltipWrapper>
    </div>
  );
};
