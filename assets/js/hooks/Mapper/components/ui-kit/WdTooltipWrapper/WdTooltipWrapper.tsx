import React, { HTMLProps, MouseEventHandler, useCallback, useRef } from 'react';

import classes from './WdTooltipWrapper.module.scss';
import clsx from 'clsx';
import { WithChildren, WithClassName } from '@/hooks/Mapper/types/common';
import { TooltipProps, WdTooltip, WdTooltipHandlers } from '@/hooks/Mapper/components/ui-kit';

type TooltipSize = 'xs' | 'sm' | 'md' | 'lg';

export type WdTooltipWrapperProps = {
  content?: (() => React.ReactNode) | React.ReactNode;
  size?: TooltipSize;
} & WithChildren &
  WithClassName &
  Omit<HTMLProps<HTMLDivElement>, 'content' | 'size'> &
  Omit<TooltipProps, 'content'>;

export const WdTooltipWrapper = ({
  className,
  children,
  content,
  offset,
  position,
  targetSelector,
  interactive = false,
  size,
  ...props
}: WdTooltipWrapperProps) => {
  const tooltipRef = useRef<WdTooltipHandlers>(null);

  const handleShowTooltip: MouseEventHandler = useCallback(e => {
    tooltipRef.current?.show(e);
  }, []);
  const handleHideTooltip: MouseEventHandler = useCallback(e => {
    tooltipRef.current?.hide(e);
  }, []);

  const sizeClass = size
    ? clsx({
        [classes.wdTooltipSizeXs]: size === 'xs',
        [classes.wdTooltipSizeSm]: size === 'sm',
        [classes.wdTooltipSizeMd]: size === 'md',
        [classes.wdTooltipSizeLg]: size === 'lg',
      })
    : undefined;

  return (
    <>
      <div
        className={clsx(classes.WdTooltipWrapperRoot, className)}
        {...props}
        {...(content && {
          onMouseEnter: handleShowTooltip,
          ...(interactive ? {} : { onMouseLeave: handleHideTooltip }),
        })}
      >
        {children}
      </div>

      <WdTooltip
        ref={tooltipRef}
        offset={offset}
        position={position}
        content={content}
        interactive={interactive}
        targetSelector={targetSelector}
        className={sizeClass}
      />
    </>
  );
};
