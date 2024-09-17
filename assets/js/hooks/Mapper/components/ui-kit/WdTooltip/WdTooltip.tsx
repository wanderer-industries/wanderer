import React, {
  ForwardedRef,
  forwardRef,
  MouseEvent,
  MouseEventHandler,
  useCallback,
  useEffect,
  useImperativeHandle,
  useRef,
  useState,
} from 'react';
import { createPortal } from 'react-dom';

import classes from './WdTooltip.module.scss';
import clsx from 'clsx';
import debounce from 'lodash.debounce';
import { WithClassName } from '@/hooks/Mapper/types/common.ts';

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
}

export interface WdTooltipHandlers {
  show: MouseEventHandler;
  hide: MouseEventHandler;
}

export interface OffsetPosition {
  top: number;
  left: number;
}

// eslint-disable-next-line react/display-name
export const WdTooltip = forwardRef((props: TooltipProps & WithClassName, ref: ForwardedRef<WdTooltipHandlers>) => {
  const { content, targetSelector, position: tPosition = TooltipPosition.default, className, offset = 5 } = props;

  const [visible, setVisible] = useState(false);
  const [position, setPosition] = useState<OffsetPosition | null>(null);
  const [ev, setEv] = useState<MouseEvent>();
  const tooltipRef = useRef<HTMLDivElement>(null);

  const calcTooltipPosition = useCallback(({ x, y }: { x: number; y: number }) => {
    let newLeft = x;
    let newTop = y;

    if (!tooltipRef.current) {
      return { left: newLeft, top: newTop };
    }

    const tooltipWidth = tooltipRef.current.offsetWidth;
    const tooltipHeight = tooltipRef.current.offsetHeight;

    if (newLeft < 0) {
      newLeft = 10;
    }

    if (newTop < 0) {
      newTop = 10;
    }

    if (newLeft + tooltipWidth + 10 > window.innerWidth) {
      newLeft = window.innerWidth - tooltipWidth - 10;
    }
    if (newTop + tooltipHeight + 10 > window.innerHeight) {
      newTop = window.innerHeight - tooltipHeight - 10;
    }
    return { left: newLeft, top: newTop };
  }, []);

  useEffect(() => {
    if (!tooltipRef.current || !ev) {
      return;
    }

    const { clientX, clientY, target } = ev;

    const targetBounds = (target as HTMLElement).getBoundingClientRect();
    const tooltipBounds = tooltipRef.current.getBoundingClientRect();

    let offsetX = clientX;
    let offsetY = clientY;

    if (tPosition === TooltipPosition.left) {
      offsetX = targetBounds.left - tooltipBounds.width - offset;
      offsetY = targetBounds.y + targetBounds.height / 2 - tooltipBounds.height / 2;

      if (offsetX <= 0) {
        offsetX = targetBounds.left + targetBounds.width + offset;
      }

      setPosition(calcTooltipPosition({ x: offsetX, y: offsetY }));
      return;
    }

    if (tPosition === TooltipPosition.right) {
      offsetX = targetBounds.left + targetBounds.width + offset;
      offsetY = targetBounds.y + targetBounds.height / 2 - tooltipBounds.height / 2;

      setPosition(calcTooltipPosition({ x: offsetX, y: offsetY }));
      return;
    }

    if (tPosition === TooltipPosition.top) {
      offsetY = targetBounds.top - tooltipBounds.height - offset;
      offsetX = targetBounds.x + targetBounds.width / 2 - tooltipBounds.width / 2;

      setPosition(calcTooltipPosition({ x: offsetX, y: offsetY }));
      return;
    }

    // default case
    setPosition(calcTooltipPosition({ x: clientX, y: clientY }));
  }, [calcTooltipPosition, ev, tPosition, offset]);

  useImperativeHandle(ref, () => ({
    show: e => {
      setEv(e);
      setVisible(true);
      setPosition(null);
    },
    hide: () => {
      setVisible(false);
    },
  }));

  useEffect(() => {
    if (targetSelector == null) {
      return;
    }

    const handleMouseMove = (e: MouseEvent) => {
      const targetElement = e.target as HTMLElement;

      if (!targetElement) {
        setVisible(false);
        return;
      }

      const nodesFound = [...(targetElement?.parentElement?.querySelectorAll(targetSelector) ?? [])];

      if (!nodesFound.includes(targetElement)) {
        setVisible(false);
        return;
      }

      setVisible(true);
      if (tooltipRef.current) {
        const { clientX, clientY } = e;
        const tooltipWidth = tooltipRef.current.offsetWidth;
        const tooltipHeight = tooltipRef.current.offsetHeight;
        let newLeft = clientX + 10;
        let newTop = clientY + 10;
        if (newLeft + tooltipWidth + 10 > window.innerWidth) {
          newLeft = window.innerWidth - tooltipWidth - 10;
        }
        if (newTop + tooltipHeight + 10 > window.innerHeight) {
          newTop = window.innerHeight - tooltipHeight - 10;
        }
        setPosition({ top: newTop, left: newLeft });
      }
    };

    const deb = debounce(handleMouseMove, 10);

    // eslint-disable-next-line @typescript-eslint/ban-ts-comment
    // @ts-expect-error
    document.addEventListener('mousemove', deb);
    return () => {
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-expect-error
      document.removeEventListener('mousemove', deb);
    };
  }, [targetSelector]);

  return createPortal(
    visible && (
      <div
        ref={tooltipRef}
        className={clsx(
          classes.tooltip,
          'pointer-events-none',
          'absolute px-2 py-2',
          'border rounded border-green-300 border-opacity-10 bg-stone-900 bg-opacity-90',
          { ['invisible']: position === null },
          className,
        )}
        style={{
          top: position?.top ?? 0,
          left: position?.left ?? 0,
          zIndex: 10000,
        }}
      >
        {typeof content === 'function' ? content() : content}
      </div>
    ),
    document.body,
  );
});
