import React, { ForwardedRef, forwardRef, useCallback, useEffect, useImperativeHandle, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import clsx from 'clsx';
import debounce from 'lodash.debounce';
import classes from './WdTooltip.module.scss';

export enum TooltipPosition {
  default = 'default',
  left = 'left',
  right = 'right',
  top = 'top',
  bottom = 'bottom',
}

export interface TooltipProps extends Omit<React.HTMLAttributes<HTMLDivElement>, 'content'> {
  position?: TooltipPosition;
  offset?: number;
  content: (() => React.ReactNode) | React.ReactNode;
  targetSelector?: string;
  interactive?: boolean;
}

export interface OffsetPosition {
  top: number;
  left: number;
}

export interface WdTooltipHandlers {
  show: (e?: React.MouseEvent) => void;
  hide: () => void;
  getIsMouseInside: () => boolean;
}

const LEAVE_DELAY = 100;

export const WdTooltip = forwardRef(function WdTooltip(
  {
    content,
    targetSelector,
    position: tPosition = TooltipPosition.default,
    offset = 5,
    interactive = false,
    className,
    ...restProps
  }: TooltipProps,
  ref: ForwardedRef<WdTooltipHandlers>,
) {
  const [visible, setVisible] = useState(false);
  const [pos, setPos] = useState<OffsetPosition | null>(null);
  const tooltipRef = useRef<HTMLDivElement>(null);

  const [isMouseInsideTooltip, setIsMouseInsideTooltip] = useState(false);

  const [reactEvt, setReactEvt] = useState<React.MouseEvent>();

  const hideTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const calcTooltipPosition = useCallback(({ x, y }: { x: number; y: number }) => {
    if (!tooltipRef.current) return { left: x, top: y };

    const tooltipWidth = tooltipRef.current.offsetWidth;
    const tooltipHeight = tooltipRef.current.offsetHeight;

    let newLeft = x;
    let newTop = y;

    if (newLeft < 0) newLeft = 10;
    if (newTop < 0) newTop = 10;

    const rightEdge = newLeft + tooltipWidth + 10;
    if (rightEdge > window.innerWidth) {
      newLeft = window.innerWidth - tooltipWidth - 10;
    }

    const bottomEdge = newTop + tooltipHeight + 10;
    if (bottomEdge > window.innerHeight) {
      newTop = window.innerHeight - tooltipHeight - 10;
    }

    return { left: newLeft, top: newTop };
  }, []);

  const scheduleHide = useCallback(() => {
    if (!interactive) {
      setVisible(false);
      return;
    }
    if (!hideTimeoutRef.current) {
      hideTimeoutRef.current = setTimeout(() => {
        setVisible(false);
      }, LEAVE_DELAY);
    }
  }, [interactive]);

  useImperativeHandle(ref, () => ({
    show: (e?: React.MouseEvent) => {
      if (hideTimeoutRef.current) {
        clearTimeout(hideTimeoutRef.current);
        hideTimeoutRef.current = null;
      }
      if (e && tooltipRef.current) {
        const { clientX, clientY } = e;
        setPos(calcTooltipPosition({ x: clientX, y: clientY }));
        setReactEvt(e);
      }
      setVisible(true);
    },
    hide: () => {
      if (hideTimeoutRef.current) {
        clearTimeout(hideTimeoutRef.current);
      }
      setVisible(false);
    },
    getIsMouseInside: () => isMouseInsideTooltip,
  }));

  useEffect(() => {
    if (!tooltipRef.current || !reactEvt) return;

    const { clientX, clientY, target } = reactEvt;
    const tooltipEl = tooltipRef.current;
    const triggerEl = target as HTMLElement;
    const triggerBounds = triggerEl.getBoundingClientRect();

    let x = clientX;
    let y = clientY;

    if (tPosition === TooltipPosition.left) {
      const tooltipBounds = tooltipEl.getBoundingClientRect();
      x = triggerBounds.left - tooltipBounds.width - offset;
      y = triggerBounds.y + triggerBounds.height / 2 - tooltipBounds.height / 2;
      if (x <= 0) {
        x = triggerBounds.left + triggerBounds.width + offset;
      }
      setPos(calcTooltipPosition({ x, y }));
      return;
    }
    if (tPosition === TooltipPosition.right) {
      x = triggerBounds.left + triggerBounds.width + offset;
      y = triggerBounds.y + triggerBounds.height / 2 - tooltipEl.offsetHeight / 2;
      setPos(calcTooltipPosition({ x, y }));
      return;
    }
    if (tPosition === TooltipPosition.top) {
      x = triggerBounds.x + triggerBounds.width / 2 - tooltipEl.offsetWidth / 2;
      y = triggerBounds.top - tooltipEl.offsetHeight - offset;
      setPos(calcTooltipPosition({ x, y }));
      return;
    }
    if (tPosition === TooltipPosition.bottom) {
      x = triggerBounds.x + triggerBounds.width / 2 - tooltipEl.offsetWidth / 2;
      y = triggerBounds.bottom + offset;
      setPos(calcTooltipPosition({ x, y }));
      return;
    }

    setPos(calcTooltipPosition({ x, y }));
  }, [calcTooltipPosition, reactEvt, tPosition, offset]);

  useEffect(() => {
    if (!targetSelector) return;

    const handleMouseMove = (evt: MouseEvent) => {
      const targetEl = evt.target as HTMLElement | null;
      if (!targetEl) {
        scheduleHide();
        return;
      }
      const triggerEl = targetEl.closest(targetSelector);
      const insideTooltip = interactive && tooltipRef.current?.contains(targetEl);

      if (!triggerEl && !insideTooltip) {
        scheduleHide();
        return;
      }

      if (hideTimeoutRef.current) {
        clearTimeout(hideTimeoutRef.current);
        hideTimeoutRef.current = null;
      }
      setVisible(true);

      if (triggerEl && tooltipRef.current) {
        const rect = triggerEl.getBoundingClientRect();
        const tooltipEl = tooltipRef.current;

        let x = evt.clientX;
        let y = evt.clientY;

        switch (tPosition) {
          case TooltipPosition.left: {
            x = rect.left - tooltipEl.offsetWidth - offset;
            y = rect.y + rect.height / 2 - tooltipEl.offsetHeight / 2;
            if (x <= 0) {
              x = rect.left + rect.width + offset;
            }
            break;
          }
          case TooltipPosition.right: {
            x = rect.left + rect.width + offset;
            y = rect.y + rect.height / 2 - tooltipEl.offsetHeight / 2;
            break;
          }
          case TooltipPosition.top: {
            x = rect.x + rect.width / 2 - tooltipEl.offsetWidth / 2;
            y = rect.top - tooltipEl.offsetHeight - offset;
            break;
          }
          case TooltipPosition.bottom: {
            x = rect.x + rect.width / 2 - tooltipEl.offsetWidth / 2;
            y = rect.bottom + offset;
            break;
          }
          default:
        }

        setPos(calcTooltipPosition({ x, y }));
      }
    };

    const debounced = debounce(handleMouseMove, 15);
    const listener = (evt: Event) => {
      debounced(evt as MouseEvent);
    };

    document.addEventListener('mousemove', listener);
    return () => {
      document.removeEventListener('mousemove', listener);
      debounced.cancel();
    };
  }, [targetSelector, interactive, tPosition, offset, calcTooltipPosition, scheduleHide]);

  useEffect(() => {
    return () => {
      if (hideTimeoutRef.current) {
        clearTimeout(hideTimeoutRef.current);
      }
    };
  }, []);

  if (!visible) return null;

  return createPortal(
    <div
      ref={tooltipRef}
      className={clsx(
        classes.tooltip,
        interactive ? 'pointer-events-auto' : 'pointer-events-none',
        'absolute p-1 border rounded-sm border-green-300 border-opacity-10 bg-stone-900 bg-opacity-90',
        pos === null ? 'invisible' : '',
        className,
      )}
      style={{
        top: pos?.top ?? 0,
        left: pos?.left ?? 0,
        zIndex: 10000,
      }}
      onMouseEnter={() => {
        if (interactive && hideTimeoutRef.current) {
          clearTimeout(hideTimeoutRef.current);
          hideTimeoutRef.current = null;
        }
        setIsMouseInsideTooltip(true);
      }}
      onMouseLeave={() => {
        setIsMouseInsideTooltip(false);
        if (interactive) {
          scheduleHide();
        }
      }}
      {...restProps}
    >
      {typeof content === 'function' ? content() : content}
    </div>,
    document.body,
  );
});

WdTooltip.displayName = 'WdTooltip';
