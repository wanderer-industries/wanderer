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
  smallPaddings?: boolean;
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

interface TriggerInfo {
  clientX: number;
  clientY: number;
  rect: DOMRect;
}

const LEAVE_DELAY = 100;

export const WdTooltip = forwardRef(
  (
    {
      content,
      targetSelector,
      position: tPosition = TooltipPosition.default,
      offset = 5,
      interactive = false,
      smallPaddings = false,
      className,
      ...restProps
    }: TooltipProps,
    ref: ForwardedRef<WdTooltipHandlers>,
  ) => {
    // Always initialize position so we never have a null value.
    const [visible, setVisible] = useState(false);
    const [pos, setPos] = useState<OffsetPosition | null>(null);
    const tooltipRef = useRef<HTMLDivElement>(null);

    const [isMouseInsideTooltip, setIsMouseInsideTooltip] = useState(false);

    const [triggerInfo, setTriggerInfo] = useState<TriggerInfo | null>(null);

    const hideTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

    const calcTooltipPosition = useCallback(({ x, y }: { x: number; y: number }) => {
      if (!tooltipRef.current) return { left: x, top: y };

      const tooltipWidth = tooltipRef.current.offsetWidth;
      const tooltipHeight = tooltipRef.current.offsetHeight;

      let newLeft = x;
      let newTop = y;

      if (newLeft < 0) {
        newLeft = 10;
      }

      if (newTop < 0) {
        newTop = 10;
      }

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
        setPos(null);
        return;
      }
      if (!hideTimeoutRef.current) {
        hideTimeoutRef.current = setTimeout(() => {
          setVisible(false);
          setPos(null);
        }, LEAVE_DELAY);
      }
    }, [interactive]);

    useImperativeHandle(ref, () => ({
      show: (e?: React.MouseEvent) => {
        if (hideTimeoutRef.current) {
          clearTimeout(hideTimeoutRef.current);
          hideTimeoutRef.current = null;
        }
        if (e) {
          // Use e.currentTarget (or fallback to e.target) to determine the trigger element.
          const triggerEl = (e.currentTarget as HTMLElement) || (e.target as HTMLElement);
          if (triggerEl) {
            const rect = triggerEl.getBoundingClientRect();
            setTriggerInfo({ clientX: e.clientX, clientY: e.clientY, rect });
          }
        }
        setVisible(true);
      },
      hide: () => {
        if (hideTimeoutRef.current) {
          clearTimeout(hideTimeoutRef.current);
        }
        setVisible(false);
        setPos(null);
      },
      getIsMouseInside: () => isMouseInsideTooltip,
    }));

    useEffect(() => {
      if (!tooltipRef.current || !triggerInfo) return;

      const tooltipEl = tooltipRef.current;
      const { rect } = triggerInfo;
      let x = triggerInfo.clientX;
      let y = triggerInfo.clientY;

      if (tPosition === TooltipPosition.left) {
        const tooltipBounds = tooltipEl.getBoundingClientRect();
        x = rect.left - tooltipBounds.width - offset;
        y = rect.top + rect.height / 2 - tooltipBounds.height / 2;

        if (x <= 0) {
          x = rect.left + rect.width + offset;
        }

        setPos(calcTooltipPosition({ x, y }));
        return;
      }

      if (tPosition === TooltipPosition.right) {
        x = rect.left + rect.width + offset;
        y = rect.top + rect.height / 2 - tooltipEl.offsetHeight / 2;
        setPos(calcTooltipPosition({ x, y }));
        return;
      }

      if (tPosition === TooltipPosition.top) {
        x = rect.left + rect.width / 2 - tooltipEl.offsetWidth / 2;
        y = rect.top - tooltipEl.offsetHeight - offset;
        setPos(calcTooltipPosition({ x, y }));
        return;
      }

      if (tPosition === TooltipPosition.bottom) {
        x = rect.left + rect.width / 2 - tooltipEl.offsetWidth / 2;
        y = rect.bottom + offset;
        setPos(calcTooltipPosition({ x, y }));
        return;
      }

      // Default case: use stored coordinates.
      setPos(calcTooltipPosition({ x, y }));
    }, [calcTooltipPosition, triggerInfo, tPosition, offset]);

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
            case TooltipPosition.left:
              x = rect.left - tooltipEl.offsetWidth - offset;
              y = rect.top + rect.height / 2 - tooltipEl.offsetHeight / 2;

              if (x <= 0) {
                x = rect.left + rect.width + offset;
              }
              break;
            case TooltipPosition.right:
              x = rect.left + rect.width + offset;
              y = rect.top + rect.height / 2 - tooltipEl.offsetHeight / 2;
              break;
            case TooltipPosition.top:
              x = rect.left + rect.width / 2 - tooltipEl.offsetWidth / 2;
              y = rect.top - tooltipEl.offsetHeight - offset;
              break;
            case TooltipPosition.bottom:
              x = rect.left + rect.width / 2 - tooltipEl.offsetWidth / 2;
              y = rect.bottom + offset;
              break;
          }

          setPos(calcTooltipPosition({ x, y }));
        }
      };

      const debounced = debounce(handleMouseMove, 15);

      document.addEventListener('mousemove', debounced);
      return () => {
        document.removeEventListener('mousemove', debounced);
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

    if (!visible) {
      return null;
    }

    return createPortal(
      <div
        ref={tooltipRef}
        className={clsx(
          classes.tooltip,
          'absolute px-2 py-1',
          'border rounded-sm border-green-300 border-opacity-10 bg-stone-900 bg-opacity-90',
          {
            'pointer-events-auto': interactive,
            'pointer-events-none': !interactive,
            invisible: pos == null,
            '!px-1': smallPaddings,
          },
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
  },
);

WdTooltip.displayName = 'WdTooltip';
