import { WdButton } from '@/hooks/Mapper/components/ui-kit/WdButton.tsx';
import { ShipSizeStatus } from '@/hooks/Mapper/types';
import clsx from 'clsx';
import { BUILT_IN_TOOLTIP_OPTIONS } from './constants.ts';
import {
  SHIP_SIZES_DESCRIPTION,
  SHIP_SIZES_NAMES,
  SHIP_SIZES_NAMES_ORDER,
  SHIP_SIZES_NAMES_SHORT,
  SHIP_SIZES_SIZE,
} from '@/hooks/Mapper/components/map/constants.ts';

const SHIP_SIZE_STYLES: Record<ShipSizeStatus, { className: string; inactiveClassName: string }> = {
  [ShipSizeStatus.small]: {
    className: 'bg-indigo-400 hover:!bg-indigo-400',
    inactiveClassName: 'bg-indigo-400/30',
  },
  [ShipSizeStatus.medium]: {
    className: 'bg-cyan-500 hover:!bg-cyan-500',
    inactiveClassName: 'bg-cyan-500/30',
  },
  [ShipSizeStatus.large]: {
    className: 'bg-indigo-300 hover:!bg-indigo-300',
    inactiveClassName: 'bg-indigo-300/30',
  },
  [ShipSizeStatus.freight]: {
    className: 'bg-indigo-300 hover:!bg-indigo-300',
    inactiveClassName: 'bg-indigo-300/30',
  },
  [ShipSizeStatus.capital]: {
    className: 'bg-indigo-300 hover:!bg-indigo-300',
    inactiveClassName: 'bg-indigo-300/30',
  },
};

export interface WdShipSizeSelectorProps {
  shipSize?: ShipSizeStatus;
  onChangeShipSize(shipSize: ShipSizeStatus): void;
  className?: string;
}

export const WdShipSizeSelector = ({
  shipSize = ShipSizeStatus.large,
  onChangeShipSize,
  className,
}: WdShipSizeSelectorProps) => {
  return (
    <form>
      <div className={clsx('grid grid-cols-[1fr_1fr_1fr_1fr_1fr] gap-1', className)}>
        {SHIP_SIZES_NAMES_ORDER.map(size => {
          const style = SHIP_SIZE_STYLES[size];
          const tooltip = `${SHIP_SIZES_NAMES[size]} • ${SHIP_SIZES_SIZE[size]} t. ${SHIP_SIZES_DESCRIPTION[size]}`;

          return (
            <WdButton
              key={size}
              outlined={false}
              value={SHIP_SIZES_NAMES_SHORT[size]}
              tooltip={tooltip}
              tooltipOptions={BUILT_IN_TOOLTIP_OPTIONS}
              size="small"
              className={clsx(
                `py-[1px] justify-center min-w-auto w-auto border-0 text-[11px] font-bold leading-[20px]`,
                { [style.inactiveClassName]: shipSize !== size },
                style.className,
              )}
              onClick={() => onChangeShipSize(size)}
            >
              <span className="text-[11px] font-bold">{SHIP_SIZES_NAMES_SHORT[size]}</span>
            </WdButton>
          );
        })}
      </div>
    </form>
  );
};
