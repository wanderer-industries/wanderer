import { LayoutEventBlocker } from '@/hooks/Mapper/components/ui-kit';
import { Button } from 'primereact/button';
import clsx from 'clsx';
import { TimeStatus } from '@/hooks/Mapper/types';

const LIFE_TIME = [
  {
    id: TimeStatus._1h,
    label: '1H',
    className: 'bg-purple-400 hover:!bg-purple-400',
    inactiveClassName: 'bg-purple-400/30',
  },
  {
    id: TimeStatus._4h,
    label: '4H',
    className: 'bg-purple-300 hover:!bg-purple-300',
    inactiveClassName: 'bg-purple-300/30',
  },
  {
    id: TimeStatus._4h30m,
    label: '4.5H',
    className: 'bg-indigo-300 hover:!bg-indigo-300',
    inactiveClassName: 'bg-indigo-300/30',
  },
  {
    id: TimeStatus._8h,
    label: '16H',
    className: 'bg-orange-300 hover:!bg-orange-300',
    inactiveClassName: 'bg-orange-400/30',
  },
  {
    id: TimeStatus._16h,
    label: '24H',
    className: 'bg-orange-300 hover:!bg-orange-300',
    inactiveClassName: 'bg-orange-400/30',
  },
  {
    id: TimeStatus._24h,
    label: '48H',
    className: 'bg-orange-300 hover:!bg-orange-300',
    inactiveClassName: 'bg-orange-400/30',
  },
];

// const active = 1;

interface LifetimeActionsProps {
  lifetime?: TimeStatus;
  onChangeLifetime(lifetime: TimeStatus): void;
}

export const LifetimeActions = ({ lifetime = TimeStatus._24h, onChangeLifetime }: LifetimeActionsProps) => {
  return (
    <LayoutEventBlocker className="flex flex-col gap-1 w-[100%] h-full px-2 pt-[4px]">
      <div className="text-[12px] text-stone-500 font-semibold">Life time:</div>

      <div className="grid grid-cols-[1fr_1fr_1fr_1fr_1fr_1fr] gap-1">
        {LIFE_TIME.map(x => (
          <Button
            outlined={false}
            // severity="help"
            key={x.id}
            value={x.label}
            size="small"
            className={clsx(
              `py-[1px] justify-center min-w-auto w-auto border-0 text-[12px] font-bold leading-[20px]`,
              { [x.inactiveClassName]: lifetime !== x.id },
              x.className,
            )}
            onClick={() => onChangeLifetime(x.id)}
            // onClick={() => system?.tag !== x && onSystemTag(x)}
          >
            {x.label}
          </Button>
        ))}
      </div>
    </LayoutEventBlocker>
  );
};
