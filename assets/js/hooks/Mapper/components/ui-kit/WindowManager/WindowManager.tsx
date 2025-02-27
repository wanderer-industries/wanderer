import React, { useState, useRef, useEffect, useMemo, useCallback } from 'react';
import styles from './WindowManager.module.scss';
import debounce from 'lodash.debounce';
import { WindowProps } from '@/hooks/Mapper/components/ui-kit/WindowManager/types.ts';
import fastDeepEqual from 'fast-deep-equal';

const MIN_WINDOW_SIZE = 100;
const SNAP_THRESHOLD = 10;
export const SNAP_GAP = 10;

export enum ActionType {
  Drag = 'drag',
  Resize = 'resize',
}

export const DefaultWindowState = {
  x: 0,
  y: 0,
  width: 0,
  height: 0,
};

function getWindowsBySides(windows: WindowProps[], containerWidth: number, containerHeight: number) {
  const centerX = containerWidth / 2;
  const centerY = containerHeight / 2;

  const top = windows.filter(window => window.position.y + window.size.height / 2 < centerY);
  const bottom = windows.filter(window => window.position.y + window.size.height / 2 >= centerY);
  const left = windows.filter(window => window.position.x + window.size.width / 2 < centerX);
  const right = windows.filter(window => window.position.x + window.size.width / 2 >= centerX);

  return { top, bottom, left, right };
}

export type WindowWrapperProps = {
  onDrag: (e: React.MouseEvent, windowId: string | number) => void;
  onResize: (e: React.MouseEvent, windowId: string | number, resizeDirection: string) => void;
} & WindowProps;

export const WindowWrapper = ({ onResize, onDrag, ...window }: WindowWrapperProps) => {
  const handleMouseDownRoot = (e: React.MouseEvent) => {
    onDrag(e, window.id);
  };

  const { handleResizeTL, handleResizeTR, handleResizeBL, handleResizeBR } = useMemo(() => {
    const handleResizeTL = (e: React.MouseEvent) => onResize(e, window.id, 'top left');
    const handleResizeTR = (e: React.MouseEvent) => onResize(e, window.id, 'top right');
    const handleResizeBL = (e: React.MouseEvent) => onResize(e, window.id, 'bottom left');
    const handleResizeBR = (e: React.MouseEvent) => onResize(e, window.id, 'bottom right');

    return {
      handleResizeTL,
      handleResizeTR,
      handleResizeBL,
      handleResizeBR,
    };
  }, [window]);

  return (
    <div
      key={window.id}
      className={`drag-handle ${styles.window}`}
      style={{
        width: window.size.width,
        height: window.size.height,
        top: window.position.y,
        left: window.position.x,
        zIndex: window.zIndex,
      }}
      onMouseDown={handleMouseDownRoot}
    >
      {window.content(window)}
      <div className={styles.resizeHandle + ' ' + styles.topLeft} onMouseDown={handleResizeTL} />
      <div className={styles.resizeHandle + ' ' + styles.topRight} onMouseDown={handleResizeTR} />
      <div className={styles.resizeHandle + ' ' + styles.bottomLeft} onMouseDown={handleResizeBL} />
      <div className={styles.resizeHandle + ' ' + styles.bottomRight} onMouseDown={handleResizeBR} />
    </div>
  );
};
export type ViewPortProps = { w: number; h: number };
export type WindowsManagerOnChange = (props: { windows: WindowProps[]; viewPort: ViewPortProps }) => void;

type WindowManagerProps = {
  windows: WindowProps[];
  viewPort?: ViewPortProps;
  dragSelector?: string;
  onChange?: WindowsManagerOnChange;
};

export const WindowManager: React.FC<WindowManagerProps> = ({
  windows: initialWindows,
  viewPort,
  dragSelector,
  onChange,
}) => {
  const [windows, setWindows] = useState(
    initialWindows.map((window, index) => ({
      ...window,
      zIndex: index + 1,
    })),
  );

  const refPrevSize = useRef({ w: 0, h: 0 });
  const ref = useRef({ windows, viewPort, onChange });
  ref.current = { windows, viewPort, onChange };

  useEffect(() => {
    if (!viewPort) {
      return;
    }

    refPrevSize.current = viewPort;
  }, [viewPort]);

  useEffect(() => {
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const next = initialWindows.map(({ content, ...x }) => x);
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const prev = ref.current.windows.map(({ content, ...x }) => x);

    // Here we avoid unnecessary renders if changes was emitted from here.
    if (fastDeepEqual(next, prev)) {
      return;
    }

    setWindows(initialWindows.slice(0));
  }, [initialWindows]);

  const containerRef = useRef<HTMLDivElement | null>(null);
  const activeWindowIdRef = useRef<string | number | null>(null);
  const actionTypeRef = useRef<ActionType | null>(null);
  const resizeDirectionRef = useRef<string | null>(null);
  const startMousePositionRef = useRef<{ x: number; y: number }>({ x: 0, y: 0 });
  const startWindowStateRef = useRef<{ x: number; y: number; width: number; height: number }>(DefaultWindowState);

  const onDebouncedChange = useMemo(() => {
    return debounce(() => {
      ref.current.onChange?.({
        windows: ref.current.windows,
        viewPort: refPrevSize.current,
      });
    }, 20);
  }, []);

  const handleMouseDown = (
    e: React.MouseEvent,
    windowId: string | number,
    actionType: ActionType,
    resizeDirection?: string,
  ) => {
    if (dragSelector && actionType === ActionType.Drag && !(e.target as HTMLElement).closest(dragSelector)) {
      return;
    }

    e.stopPropagation();
    activeWindowIdRef.current = windowId;
    actionTypeRef.current = actionType;
    resizeDirectionRef.current = resizeDirection || null;
    startMousePositionRef.current = { x: e.clientX, y: e.clientY };
    const targetWindow = windows.find(win => win.id === windowId);
    if (targetWindow) {
      startWindowStateRef.current = {
        x: targetWindow.position.x,
        y: targetWindow.position.y,
        width: targetWindow.size.width,
        height: targetWindow.size.height,
      };
    }

    // Bring window to front by updating zIndex
    setWindows(prevWindows => {
      const maxZIndex = Math.max(...prevWindows.map(w => w.zIndex));
      return prevWindows.map(window => (window.id === windowId ? { ...window, zIndex: maxZIndex + 1 } : window));
    });

    window.addEventListener('mousemove', handleMouseMove);
    window.addEventListener('mouseup', handleMouseUp);
  };

  const handleMouseMove = (e: MouseEvent) => {
    if (activeWindowIdRef.current !== null && actionTypeRef.current) {
      const deltaX = e.clientX - startMousePositionRef.current.x;
      const deltaY = e.clientY - startMousePositionRef.current.y;
      const container = containerRef.current;

      setWindows(prevWindows =>
        prevWindows.map(window => {
          if (window.id === activeWindowIdRef.current) {
            let newX = startWindowStateRef.current.x;
            let newY = startWindowStateRef.current.y;
            let newWidth = startWindowStateRef.current.width;
            let newHeight = startWindowStateRef.current.height;

            if (actionTypeRef.current === ActionType.Drag) {
              newX += deltaX;
              newY += deltaY;

              // Ensure the window stays within the container boundaries
              if (container) {
                newX = Math.max(SNAP_GAP, Math.min(container.clientWidth - window.size.width - SNAP_GAP, newX));
                newY = Math.max(SNAP_GAP, Math.min(container.clientHeight - window.size.height - SNAP_GAP, newY));
              }

              // Snap to other windows with or without gap
              prevWindows.forEach(otherWindow => {
                if (otherWindow.id === window.id) {
                  return;
                }

                // Snap vertically (top and bottom)
                if (Math.abs(newY - otherWindow.position.y) < SNAP_THRESHOLD) {
                  newY = otherWindow.position.y; // Align top without gap
                } else if (Math.abs(newY + window.size.height - otherWindow.position.y) < SNAP_THRESHOLD) {
                  newY = otherWindow.position.y - window.size.height - SNAP_GAP; // Bottom aligns to top
                } else if (Math.abs(newY - (otherWindow.position.y + otherWindow.size.height)) < SNAP_THRESHOLD) {
                  newY = otherWindow.position.y + otherWindow.size.height + SNAP_GAP; // Align bottom without gap
                } else if (
                  Math.abs(newY + window.size.height - (otherWindow.position.y + otherWindow.size.height)) <
                  SNAP_THRESHOLD
                ) {
                  newY = otherWindow.position.y + otherWindow.size.height - window.size.height; // Bottom aligns bottom
                }

                // Snap horizontally (left and right)
                if (Math.abs(newX - otherWindow.position.x) < SNAP_THRESHOLD) {
                  newX = otherWindow.position.x; // Align left without gap
                } else if (Math.abs(newX + window.size.width - otherWindow.position.x) < SNAP_THRESHOLD) {
                  newX = otherWindow.position.x - window.size.width - SNAP_GAP; // Right aligns to left
                } else if (Math.abs(newX - (otherWindow.position.x + otherWindow.size.width)) < SNAP_THRESHOLD) {
                  newX = otherWindow.position.x + otherWindow.size.width + SNAP_GAP; // Align right without gap
                } else if (
                  Math.abs(newX + window.size.width - (otherWindow.position.x + otherWindow.size.width)) <
                  SNAP_THRESHOLD
                ) {
                  newX = otherWindow.position.x + otherWindow.size.width - window.size.width; // Right aligns right
                }
              });
            }

            if (actionTypeRef.current === ActionType.Resize && resizeDirectionRef.current) {
              if (resizeDirectionRef.current.includes('right')) {
                newWidth = Math.max(MIN_WINDOW_SIZE, startWindowStateRef.current.width + deltaX);

                // Снап для правой границы с отступом SNAP_THRESHOLD
                prevWindows.forEach(otherWindow => {
                  if (otherWindow.id !== window.id) {
                    // Правая граница текущего окна к левой границе другого окна
                    const snapRightToLeft =
                      otherWindow.position.x - (startWindowStateRef.current.x + newWidth) - SNAP_THRESHOLD;
                    if (Math.abs(snapRightToLeft) < SNAP_THRESHOLD) {
                      newWidth = otherWindow.position.x - startWindowStateRef.current.x - SNAP_THRESHOLD;
                    }

                    // Правая граница текущего окна к правой границе другого окна
                    const snapRightToRight =
                      otherWindow.position.x + otherWindow.size.width - (startWindowStateRef.current.x + newWidth);
                    if (Math.abs(snapRightToRight) < SNAP_THRESHOLD) {
                      newWidth = otherWindow.position.x + otherWindow.size.width - startWindowStateRef.current.x;
                    }
                  }
                });
              }

              if (resizeDirectionRef.current.includes('left')) {
                newWidth = Math.max(MIN_WINDOW_SIZE, startWindowStateRef.current.width - deltaX);
                newX = startWindowStateRef.current.x + (startWindowStateRef.current.width - newWidth);

                // Снап для левой границы с отступом SNAP_THRESHOLD
                prevWindows.forEach(otherWindow => {
                  if (otherWindow.id !== window.id) {
                    // Левая граница текущего окна к правой границе другого окна
                    const snapLeftToRight = newX - (otherWindow.position.x + otherWindow.size.width + SNAP_THRESHOLD);
                    if (Math.abs(snapLeftToRight) < SNAP_THRESHOLD) {
                      newX = otherWindow.position.x + otherWindow.size.width + SNAP_THRESHOLD;
                      newWidth = startWindowStateRef.current.width + startWindowStateRef.current.x - newX;
                    }

                    // Левая граница текущего окна к левой границе другого окна
                    const snapLeftToLeft = newX - otherWindow.position.x;
                    if (Math.abs(snapLeftToLeft) < SNAP_THRESHOLD) {
                      newX = otherWindow.position.x;
                      newWidth = startWindowStateRef.current.width + startWindowStateRef.current.x - newX;
                    }
                  }
                });
              }

              if (resizeDirectionRef.current.includes('bottom')) {
                newHeight = Math.max(MIN_WINDOW_SIZE, startWindowStateRef.current.height + deltaY);

                // Снап для нижней границы с отступом SNAP_THRESHOLD
                prevWindows.forEach(otherWindow => {
                  if (otherWindow.id !== window.id) {
                    // Нижняя граница текущего окна к верхней границе другого окна
                    const snapBottomToTop =
                      otherWindow.position.y - (startWindowStateRef.current.y + newHeight) - SNAP_THRESHOLD;
                    if (Math.abs(snapBottomToTop) < SNAP_THRESHOLD) {
                      newHeight = otherWindow.position.y - startWindowStateRef.current.y - SNAP_THRESHOLD;
                    }

                    // Нижняя граница текущего окна к нижней границе другого окна
                    const snapBottomToBottom =
                      otherWindow.position.y + otherWindow.size.height - (startWindowStateRef.current.y + newHeight);
                    if (Math.abs(snapBottomToBottom) < SNAP_THRESHOLD) {
                      newHeight = otherWindow.position.y + otherWindow.size.height - startWindowStateRef.current.y;
                    }
                  }
                });
              }

              if (resizeDirectionRef.current.includes('top')) {
                newHeight = Math.max(MIN_WINDOW_SIZE, startWindowStateRef.current.height - deltaY);
                newY = startWindowStateRef.current.y + (startWindowStateRef.current.height - newHeight);

                // Снап для верхней границы с отступом SNAP_THRESHOLD
                prevWindows.forEach(otherWindow => {
                  if (otherWindow.id !== window.id) {
                    // Верхняя граница текущего окна к нижней границе другого окна
                    const snapTopToBottom = newY - (otherWindow.position.y + otherWindow.size.height + SNAP_THRESHOLD);
                    if (Math.abs(snapTopToBottom) < SNAP_THRESHOLD) {
                      newY = otherWindow.position.y + otherWindow.size.height + SNAP_THRESHOLD;
                      newHeight = startWindowStateRef.current.height + startWindowStateRef.current.y - newY;
                    }

                    // Верхняя граница текущего окна к верхней границе другого окна
                    const snapTopToTop = newY - otherWindow.position.y;
                    if (Math.abs(snapTopToTop) < SNAP_THRESHOLD) {
                      newY = otherWindow.position.y;
                      newHeight = startWindowStateRef.current.height + startWindowStateRef.current.y - newY;
                    }
                  }
                });
              }

              // Ensure the window stays within the container boundaries
              if (container) {
                newX = Math.max(0 + SNAP_GAP, Math.min(container.clientWidth - newWidth - SNAP_GAP, newX));
                newY = Math.max(0 + SNAP_GAP, Math.min(container.clientHeight - newHeight - SNAP_GAP, newY));
              }
            }

            return {
              ...window,
              position: { x: newX, y: newY },
              size: { width: newWidth, height: newHeight },
            };
          }
          return window;
        }),
      );

      onDebouncedChange();
    }
  };

  const handleMouseUp = useCallback(() => {
    activeWindowIdRef.current = null;
    actionTypeRef.current = null;
    resizeDirectionRef.current = null;

    onDebouncedChange();
    window.removeEventListener('mousemove', handleMouseMove);
    window.removeEventListener('mouseup', handleMouseUp);
  }, []);

  // Handle resize of the container and reposition windows
  useEffect(() => {
    if (ref.current.viewPort == null && containerRef.current) {
      refPrevSize.current = { w: containerRef.current.clientWidth, h: containerRef.current.clientHeight };
    }

    const handleResize = () => {
      const container = containerRef.current;
      const { windows } = ref.current;
      if (!container) {
        return;
      }

      const deltaX = container.clientWidth - refPrevSize.current.w;
      const deltaY = container.clientHeight - refPrevSize.current.h;

      const { bottom, right } = getWindowsBySides(windows, refPrevSize.current.w, refPrevSize.current.h);

      setWindows(w => {
        return w.map(x => {
          let next = { ...x };

          if (right.some(r => r.id === x.id)) {
            next = {
              ...next,
              position: {
                ...next.position,
                x: next.position.x + deltaX,
              },
            };
          }

          if (bottom.some(r => r.id === x.id)) {
            next = {
              ...next,
              position: {
                ...next.position,
                y: next.position.y + deltaY,
              },
            };
          }

          if (next.position.x + next.size.width > container.clientWidth - SNAP_GAP) {
            next.position.x = container.clientWidth - next.size.width - SNAP_GAP;
          }

          if (next.position.y + next.size.height > container.clientHeight - SNAP_GAP) {
            next.position.y = container.clientHeight - next.size.height - SNAP_GAP;
          }

          if (next.position.y < SNAP_GAP) {
            next.position.y = 0;
          }

          if (next.position.x < SNAP_GAP) {
            next.position.x = SNAP_GAP;
          }

          return next;
        });
      });

      onDebouncedChange();

      refPrevSize.current = { w: container.clientWidth, h: container.clientHeight };
    };

    const tid = setTimeout(handleResize, 10);
    window.addEventListener('resize', handleResize);
    return () => {
      clearTimeout(tid);
      window.removeEventListener('resize', handleResize);
    };
  }, []);

  const handleDrag = (e: React.MouseEvent, windowId: string | number) => {
    handleMouseDown(e, windowId, ActionType.Drag);
  };

  const handleResize = (e: React.MouseEvent, windowId: string | number, resizeDirection: string) => {
    handleMouseDown(e, windowId, ActionType.Resize, resizeDirection);
  };

  return (
    <div ref={containerRef} className={styles.windowContainer}>
      {windows.map(window => (
        <WindowWrapper key={window.id} onDrag={handleDrag} onResize={handleResize} {...window} />
      ))}
    </div>
  );
};
