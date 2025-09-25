import { WdButton } from '@/hooks/Mapper/components/ui-kit/WdButton.tsx';
import { TimeStatus } from '@/hooks/Mapper/types';
import clsx from 'clsx';
import { BUILT_IN_TOOLTIP_OPTIONS } from './constants.ts';

const LIFE_TIME = [
  {
    id: TimeStatus._1h,
    label: '1H',
    className: 'bg-purple-400 hover:!bg-purple-400',
    inactiveClassName: 'bg-purple-400/30',
    description: 'Less than one 1 hours remaining',
  },
  {
    id: TimeStatus._4h,
    label: '4H',
    className: 'bg-purple-300 hover:!bg-purple-300',
    inactiveClassName: 'bg-purple-300/30',
    description: 'Less than one 4 hours remaining',
  },
  {
    id: TimeStatus._4h30m,
    label: '4.5H',
    className: 'bg-indigo-300 hover:!bg-indigo-300',
    inactiveClassName: 'bg-indigo-300/30',
    description: 'Less than one 4.5 hours remaining. All small holes have such lifetime.',
  },
  {
    id: TimeStatus._16h,
    label: '16H',
    className: 'bg-orange-300 hover:!bg-orange-300',
    inactiveClassName: 'bg-orange-400/30',
    description: 'Less than one 16 hours remaining',
  },
  {
    id: TimeStatus._24h,
    label: '24H',
    className: 'bg-orange-300 hover:!bg-orange-300',
    inactiveClassName: 'bg-orange-400/30',
    description: 'Less than one 24 hours remaining',
  },
  {
    id: TimeStatus._48h,
    label: '48H',
    className: 'bg-orange-300 hover:!bg-orange-300',
    inactiveClassName: 'bg-orange-400/30',
    description: 'Less than one 24 hours remaining. Related only with C6. B041, B520, U319, C391.',
  },
];

export interface WdLifetimeSelectorProps {
  lifetime?: TimeStatus;
  onChangeLifetime(lifetime: TimeStatus): void;
  className?: string;
}

export const WdLifetimeSelector = ({
  lifetime = TimeStatus._24h,
  onChangeLifetime,
  className,
}: WdLifetimeSelectorProps) => {
  return (
    <form>
      <div className={clsx('grid grid-cols-[1fr_1fr_1fr_1fr_1fr_1fr] gap-1', className)}>
        {LIFE_TIME.map(x => (
          <WdButton
            key={x.id}
            outlined={false}
            value={x.label}
            tooltip={x.description}
            tooltipOptions={BUILT_IN_TOOLTIP_OPTIONS}
            size="small"
            className={clsx(
              `py-[1px] justify-center min-w-auto w-auto border-0 text-[12px] font-bold leading-[20px]`,
              { [x.inactiveClassName]: lifetime !== x.id },
              x.className,
            )}
            onClick={() => onChangeLifetime(x.id)}
          >
            {x.label}
          </WdButton>
        ))}
      </div>
    </form>
  );
};
