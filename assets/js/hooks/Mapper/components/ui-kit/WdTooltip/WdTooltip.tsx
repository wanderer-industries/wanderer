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

export interface TooltipProps {
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
  hide: (e?: React.MouseEvent) => void;
  getIsMouseInside: () => boolean;
}

export const WdTooltip = forwardRef(
  (props: TooltipProps & { className?: string }, ref: ForwardedRef<WdTooltipHandlers>) => {
    const {
      content,
      targetSelector,
      position: tPosition = TooltipPosition.default,
      className,
      offset = 5,
      interactive = false,
    } = props;

    const [visible, setVisible] = useState(false);
    const [pos, setPos] = useState<OffsetPosition | null>(null);
    const [ev, setEv] = useState<React.MouseEvent>();
    const tooltipRef = useRef<HTMLDivElement>(null);
    const [isMouseInsideTooltip, setIsMouseInsideTooltip] = useState(false);

    const calcTooltipPosition = useCallback(({ x, y }: { x: number; y: number }) => {
      if (!tooltipRef.current) return { left: x, top: y };
      const tooltipWidth = tooltipRef.current.offsetWidth;
      const tooltipHeight = tooltipRef.current.offsetHeight;
      let newLeft = x;
      let newTop = y;

      if (newLeft < 0) newLeft = 10;
      if (newTop < 0) newTop = 10;
      if (newLeft + tooltipWidth + 10 > window.innerWidth) {
        newLeft = window.innerWidth - tooltipWidth - 10;
      }
      if (newTop + tooltipHeight + 10 > window.innerHeight) {
        newTop = window.innerHeight - tooltipHeight - 10;
      }
      return { left: newLeft, top: newTop };
    }, []);

    useImperativeHandle(ref, () => ({
      show: (mouseEvt?: React.MouseEvent) => {
        if (mouseEvt) setEv(mouseEvt);
        setPos(null);
        setVisible(true);
      },
      hide: () => {
        setVisible(false);
      },
      getIsMouseInside: () => isMouseInsideTooltip,
    }));

    useEffect(() => {
      if (!tooltipRef.current || !ev) return;
      const tooltipEl = tooltipRef.current;
      const { clientX, clientY, target } = ev;
      const targetBounds = (target as HTMLElement).getBoundingClientRect();

      let offsetX = clientX;
      let offsetY = clientY;

      if (tPosition === TooltipPosition.left) {
        const tooltipBounds = tooltipEl.getBoundingClientRect();
        offsetX = targetBounds.left - tooltipBounds.width - offset;
        offsetY = targetBounds.y + targetBounds.height / 2 - tooltipBounds.height / 2;
        if (offsetX <= 0) {
          offsetX = targetBounds.left + targetBounds.width + offset;
        }
        setPos(calcTooltipPosition({ x: offsetX, y: offsetY }));
        return;
      }

      if (tPosition === TooltipPosition.right) {
        offsetX = targetBounds.left + targetBounds.width + offset;
        offsetY = targetBounds.y + targetBounds.height / 2 - tooltipEl.offsetHeight / 2;
        setPos(calcTooltipPosition({ x: offsetX, y: offsetY }));
        return;
      }

      if (tPosition === TooltipPosition.top) {
        offsetY = targetBounds.top - tooltipEl.offsetHeight - offset;
        offsetX = targetBounds.x + targetBounds.width / 2 - tooltipEl.offsetWidth / 2;
        setPos(calcTooltipPosition({ x: offsetX, y: offsetY }));
        return;
      }

      if (tPosition === TooltipPosition.bottom) {
        offsetY = targetBounds.bottom + offset;
        offsetX = targetBounds.x + targetBounds.width / 2 - tooltipEl.offsetWidth / 2;
        setPos(calcTooltipPosition({ x: offsetX, y: offsetY }));
        return;
      }

      setPos(calcTooltipPosition({ x: offsetX, y: offsetY }));
    }, [calcTooltipPosition, ev, tPosition, offset]);

    useEffect(() => {
      if (!targetSelector) return;

      function handleMouseMove(nativeEvt: globalThis.MouseEvent) {
        const targetEl = nativeEvt.target as HTMLElement | null;
        if (!targetEl) {
          setVisible(false);
          return;
        }
        const triggerEl = targetEl.closest(targetSelector!);
        const isInsideTooltip = interactive && tooltipRef.current?.contains(targetEl);

        if (!triggerEl && !isInsideTooltip) {
          setVisible(false);
          return;
        }
        setVisible(true);

        if (triggerEl && tooltipRef.current) {
          const rect = triggerEl.getBoundingClientRect();
          const tooltipEl = tooltipRef.current;
          let x = nativeEvt.clientX;
          let y = nativeEvt.clientY;

          if (tPosition === TooltipPosition.left) {
            x = rect.left - tooltipEl.offsetWidth - offset;
            y = rect.y + rect.height / 2 - tooltipEl.offsetHeight / 2;
            if (x <= 0) {
              x = rect.left + rect.width + offset;
            }
          } else if (tPosition === TooltipPosition.right) {
            x = rect.left + rect.width + offset;
            y = rect.y + rect.height / 2 - tooltipEl.offsetHeight / 2;
          } else if (tPosition === TooltipPosition.top) {
            x = rect.x + rect.width / 2 - tooltipEl.offsetWidth / 2;
            y = rect.top - tooltipEl.offsetHeight - offset;
          } else if (tPosition === TooltipPosition.bottom) {
            x = rect.x + rect.width / 2 - tooltipEl.offsetWidth / 2;
            y = rect.bottom + offset;
          }

          setPos(calcTooltipPosition({ x, y }));
        }
      }

      const debounced = debounce(handleMouseMove, 10);

      const listener: EventListener = evt => {
        debounced(evt as globalThis.MouseEvent);
      };

      document.addEventListener('mousemove', listener);
      return () => {
        document.removeEventListener('mousemove', listener);
      };
    }, [targetSelector, interactive, tPosition, offset, calcTooltipPosition]);

    return createPortal(
      visible && (
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
          onMouseEnter={() => interactive && setIsMouseInsideTooltip(true)}
          onMouseLeave={() => interactive && setIsMouseInsideTooltip(false)}
        >
          {typeof content === 'function' ? content() : content}
        </div>
      ),
      document.body,
    );
  },
);

WdTooltip.displayName = 'WdTooltip';
