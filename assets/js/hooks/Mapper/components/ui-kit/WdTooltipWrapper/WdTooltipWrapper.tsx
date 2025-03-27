import { forwardRef, HTMLProps, ReactNode, useMemo } from 'react';
import clsx from 'clsx';
import { WdTooltip, WdTooltipHandlers, TooltipProps } from '@/hooks/Mapper/components/ui-kit';
import classes from './WdTooltipWrapper.module.scss';
import { sizeClass, TooltipSize } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper/utils.ts';

export type WdTooltipWrapperProps = {
  content?: (() => ReactNode) | ReactNode;
  size?: TooltipSize;
  interactive?: boolean;
  tooltipClassName?: string;
} & Omit<HTMLProps<HTMLDivElement>, 'content' | 'size'> &
  Omit<TooltipProps, 'content'>;

export const WdTooltipWrapper = forwardRef<WdTooltipHandlers, WdTooltipWrapperProps>(
  (
    { className, children, content, offset, position, targetSelector, interactive, size, tooltipClassName, ...props },
    forwardedRef,
  ) => {
    const suffix = useMemo(() => Math.random().toString(36).slice(2, 7), []);
    const autoClass = `wdTooltipAutoTrigger-${suffix}`;
    const finalTargetSelector = targetSelector || `.${autoClass}`;

    return (
      <div className={clsx(classes.WdTooltipWrapperRoot, className)} {...props}>
        {targetSelector ? <>{children}</> : <div className={autoClass}>{children}</div>}

        <WdTooltip
          ref={forwardedRef}
          offset={offset}
          position={position}
          content={content}
          interactive={interactive}
          targetSelector={finalTargetSelector}
          className={clsx(size && sizeClass(size), tooltipClassName)}
        />
      </div>
    );
  },
);

WdTooltipWrapper.displayName = 'WdTooltipWrapper';
