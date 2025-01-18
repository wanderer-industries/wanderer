import React, { HTMLProps, MouseEventHandler, useCallback, useRef } from 'react';

import classes from './WdTooltipWrapper.module.scss';
import { WithChildren, WithClassName } from '@/hooks/Mapper/types/common.ts';
import { TooltipProps, WdTooltip, WdTooltipHandlers } from '@/hooks/Mapper/components/ui-kit';
import clsx from 'clsx';

export type WdTooltipWrapperProps = {
  content?: (() => React.ReactNode) | React.ReactNode;
} & WithChildren &
  WithClassName &
  HTMLProps<HTMLDivElement> &
  Omit<TooltipProps, 'content'>;

export const WdTooltipWrapper = ({
  className,
  children,
  content,
  offset,
  position,
  targetSelector,
  interactive = false,
  ...props
}: WdTooltipWrapperProps) => {
  const tooltipRef = useRef<WdTooltipHandlers>(null);
  const handleShowDeleteTooltip: MouseEventHandler = useCallback(e => tooltipRef.current?.show(e), []);
  const handleHideDeleteTooltip: MouseEventHandler = useCallback(e => tooltipRef.current?.hide(e), []);

  return (
    <>
      <div
        className={clsx(classes.WdTooltipWrapperRoot, className)}
        {...props}
        {...(content && {
          onMouseEnter: handleShowDeleteTooltip,
          ...(interactive ? {} : { onMouseLeave: handleHideDeleteTooltip }),
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
      />
    </>
  );
};
