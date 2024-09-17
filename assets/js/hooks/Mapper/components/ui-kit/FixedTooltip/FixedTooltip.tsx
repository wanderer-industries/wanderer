import { Tooltip, TooltipProps } from 'primereact/tooltip';
import clsx from 'clsx';

export const FixedTooltip = ({ children, className, ...props }: TooltipProps) => {
  return (
    <Tooltip
      className={clsx('border border-green-300 rounded border-opacity-10 bg-stone-900 bg-opacity-70', className)}
      {...props}
    >
      {children}
    </Tooltip>
  );
};
