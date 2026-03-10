import { WdButton } from '@/hooks/Mapper/components/ui-kit/WdButton.tsx';
import { MassState } from '@/hooks/Mapper/types';
import clsx from 'clsx';
import { BUILT_IN_TOOLTIP_OPTIONS } from './constants.ts';

const MASS_STATUS = [
  {
    id: MassState.verge,
    label: 'Verge',
    className: 'bg-red-400 hover:!bg-red-400',
    inactiveClassName: 'bg-red-400/30',
    description: 'Mass status: Verge of collapse',
  },
  {
    id: MassState.half,
    label: 'Half',
    className: 'bg-orange-300 hover:!bg-orange-300',
    inactiveClassName: 'bg-orange-300/30',
    description: 'Mass status: Half',
  },
  {
    id: MassState.normal,
    label: 'Normal',
    className: 'bg-indigo-300 hover:!bg-indigo-300',
    inactiveClassName: 'bg-indigo-300/30',
    description: 'Mass status: Normal',
  },
];

export interface WdMassStatusSelectorProps {
  massStatus?: MassState;
  onChangeMassStatus(massStatus: MassState): void;
  className?: string;
}

export const WdMassStatusSelector = ({
  massStatus = MassState.normal,
  onChangeMassStatus,
  className,
}: WdMassStatusSelectorProps) => {
  return (
    <form>
      <div className={clsx('grid grid-cols-[auto_auto_auto] gap-1', className)}>
        {MASS_STATUS.map(x => (
          <WdButton
            key={x.id}
            outlined={false}
            value={x.label}
            tooltip={x.description}
            tooltipOptions={BUILT_IN_TOOLTIP_OPTIONS}
            size="small"
            className={clsx(
              `py-[1px] justify-center min-w-auto w-auto border-0 text-[12px] font-bold leading-[20px]`,
              { [x.inactiveClassName]: massStatus !== x.id },
              x.className,
            )}
            onClick={() => onChangeMassStatus(x.id)}
          >
            {x.label}
          </WdButton>
        ))}
      </div>
    </form>
  );
};
