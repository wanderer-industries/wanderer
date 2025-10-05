import React, { Fragment } from 'react';
import clsx from 'clsx';
import { WdTooltipWrapper, TooltipPosition } from '@/hooks/Mapper/components/ui-kit';
import { EFFECT_NAME } from '@/hooks/Mapper/components/map/constants.ts';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { EffectRaw } from '@/hooks/Mapper/types/effect';

export interface EffectsTooltipProps {
  effectName: string;
  effectPower: number;
  children: React.ReactNode;
}
const prepareEffects = (effectsMap: Record<string, EffectRaw>, effectName: string, effectPower: number) => {
  const effect = effectsMap[effectName];

  if (!effect) return [] as { name: string; power: string; positive: boolean }[];

  const out: { name: string; power: string; positive: boolean }[] = [];

  effect.modifiers.map(mod => {
    const modPower = mod.power[effectPower - 1];
    out.push({ name: mod.name, power: modPower, positive: mod.positive });
  });

  out.sort((a, b) => (a.positive === b.positive ? 0 : a.positive ? -1 : 1));
  return out;
};

export const EffectsTooltip = ({ effectName, effectPower, children }: EffectsTooltipProps): JSX.Element => {
  const {
    data: { effects },
  } = useMapRootState();
  const tooltipContent = (
    <div className={clsx('grid grid-cols-[1fr_auto] gap-x-4 gap-y-1 text-xs p-1')}>
      {prepareEffects(effects, effectName, effectPower).map(({ name, power, positive }) => (
        <Fragment key={name}>
          <span className="text-white">{name}</span>
          <span className={clsx({ 'text-green-500': positive, 'text-red-500': !positive })}>{power}</span>
        </Fragment>
      ))}
    </div>
  );

  const gradientClassName = clsx('bg-gradient-to-br', {
    'from-black/10 to-yellow-500/10': effectName === EFFECT_NAME.cataclysmicVariable,
    'from-black/10 to-fuchsia-500/10': effectName === EFFECT_NAME.magnetar,
    'from-black/10 to-blue-500/20': effectName === EFFECT_NAME.pulsar,
    'from-black/10 to-red-500/10': effectName === EFFECT_NAME.redGiant,
    'from-black/10 to-amber-500/10': effectName === EFFECT_NAME.wolfRayetStar,
  });

  return (
    <WdTooltipWrapper
      content={tooltipContent}
      position={TooltipPosition.right}
      smallPaddings
      tooltipClassName={gradientClassName}
    >
      <div className="cursor-help">{children}</div>
    </WdTooltipWrapper>
  );
};
