import classes from './WHEffectView.module.scss';
import clsx from 'clsx';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { EFFECT_FOREGROUND_STYLES, EFFECT_NAME } from '@/hooks/Mapper/components/map/constants.ts';
import { EffectRaw } from '@/hooks/Mapper/types/effect.ts';
import { Fragment, useMemo } from 'react';
import { FixedTooltip } from '@/hooks/Mapper/components/ui-kit';

type PreparedEffectType = {
  name: string;
  power: string;
  positive: boolean;
};

const prepareEffects = (effects: Record<string, EffectRaw>, effectName: string, effectPower: number) => {
  const effect = effects[effectName];
  const out: PreparedEffectType[] = [];

  effect.modifiers.map(mod => {
    const modPower = mod.power[effectPower - 1];

    out.push({
      name: mod.name,
      power: modPower,
      positive: mod.positive,
    });
  });

  out.sort((a, b) => (a.positive === b.positive ? 0 : a.positive ? -1 : 1));

  return out;
};

let counter = 0;

export interface WHEffectViewProps {
  effectName: string;
  effectPower: number;
  className?: string;
}

export const WHEffectView = ({ effectName, effectPower, className }: WHEffectViewProps) => {
  const {
    data: { effects },
  } = useMapRootState();

  const effectClass = EFFECT_FOREGROUND_STYLES[effectName];
  const effectInfo = effects[effectName];

  const preparedEffect = useMemo(
    () => prepareEffects(effects, effectName, effectPower),
    [effectName, effectPower, effects],
  );

  const targetClass = useMemo(() => `wh-effect-name${effectInfo.id}-${counter++}`, []);

  return (
    <div className={classes.WHEffectViewRoot}>
      <FixedTooltip
        target={`.${targetClass}`}
        position="right"
        mouseTrack
        mouseTrackLeft={20}
        mouseTrackTop={30}
        className={clsx('bg-gradient-to-br ', {
          ['from-black/10 to-yellow-500/10']: effectName === EFFECT_NAME.cataclysmicVariable,
          ['from-black/10 to-fuchsia-500/10']: effectName === EFFECT_NAME.magnetar,
          ['from-black/10 to-blue-500/20']: effectName === EFFECT_NAME.pulsar,
          ['from-black/10 to-red-500/10']: effectName === EFFECT_NAME.redGiant,
          ['from-black/10 to-amber-500/10']: effectName === EFFECT_NAME.wolfRayetStar,
        })}
      >
        <div className={clsx(classes.WHEffectViewContent, 'text-xs')}>
          {preparedEffect.map(({ name, power, positive }) => (
            <Fragment key={name}>
              <span>{name}</span>
              <span
                className={clsx({
                  ['text-green-500']: positive,
                  ['text-red-500']: !positive,
                })}
              >
                {power}
              </span>
            </Fragment>
          ))}
        </div>
      </FixedTooltip>

      <div className={clsx('font-bold select-none cursor-help w-min-content', effectClass, targetClass, className)}>
        {effectName}
      </div>
    </div>
  );
};
