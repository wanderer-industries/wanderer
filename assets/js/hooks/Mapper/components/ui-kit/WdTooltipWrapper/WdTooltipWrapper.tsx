import { forwardRef, HTMLProps, ReactNode, useMemo } from 'react';
import clsx from 'clsx';
import { WdTooltip, WdTooltipHandlers, TooltipProps } from '@/hooks/Mapper/components/ui-kit';
import classes from './WdTooltipWrapper.module.scss';

type TooltipSize = 'xs' | 'sm' | 'md' | 'lg';

export type WdTooltipWrapperProps = {
  content?: (() => ReactNode) | ReactNode;
  size?: TooltipSize;
  interactive?: boolean;
} & Omit<HTMLProps<HTMLDivElement>, 'content' | 'size'> &
  Omit<TooltipProps, 'content'>;

export const WdTooltipWrapper = forwardRef<WdTooltipHandlers, WdTooltipWrapperProps>(
  ({ className, children, content, offset, position, targetSelector, interactive, size, ...props }, forwardedRef) => {
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
          className={size ? sizeClass(size) : undefined}
        />
      </div>
    );
  },
);

WdTooltipWrapper.displayName = 'WdTooltipWrapper';

function sizeClass(size: TooltipSize) {
  switch (size) {
    case 'xs':
      return classes.wdTooltipSizeXs;
    case 'sm':
      return classes.wdTooltipSizeSm;
    case 'md':
      return classes.wdTooltipSizeMd;
    case 'lg':
      return classes.wdTooltipSizeLg;
    default:
      return undefined;
  }
}
