import React, { useEffect, useRef, useState } from 'react';

import classes from './WidgetsGrid.module.scss';
import { ItemCallback, Layouts, Responsive, WidthProvider } from 'react-grid-layout';
import clsx from 'clsx';
import usePageVisibility from '@/hooks/Mapper/hooks/usePageVisibility.ts';

const ResponsiveGridLayout = WidthProvider(Responsive);

const colSize = 50;
const initState = { breakpoints: 100, cols: 2 };

export type WidgetGridItem = {
  rightOffset?: number;
  leftOffset?: number;
  topOffset?: number;
  width: number;
  height: number;
  name: string;
  item: () => React.ReactNode;
};

export interface WidgetsGridProps {
  items: WidgetGridItem[];
  onChange: (items: WidgetGridItem[]) => void;
}

export const WidgetsGrid = ({ items, onChange }: WidgetsGridProps) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const [, setKey] = useState(0);
  const [callRerenderOfGrid, setCallRerenderOfGrid] = useState(0);

  const isTabVisible = usePageVisibility();

  const refAll = useRef({
    isReady: false,
    layouts: {
      lg: [
        // { i: 'a', w: 4, h: 16, x: 22, y: 0 },
        // { i: 'b', w: 5, h: 10, x: 17, y: 0 },
      ],
    } as Layouts,
    breakpoints: { lg: 100, md: 0, sm: 0, xs: 0, xxs: 0 },
    cols: { lg: 26, md: 0, sm: 0, xs: 0, xxs: 0 },
    containerWidth: 0,
    colsPrev: 26,
    needPostProcess: false,
    items: [...items],
  });

  // TODO
  //  1. onLayoutChange (original) not calling when we change x of any widget
  //  2. setKey need no call rerender for update props
  const onLayoutChange: ItemCallback = (newItems, _, newItem) => {
    const updatedItems = newItems.map(item => {
      const toLeft = (item.x + item.w / 2) / refAll.current.cols.lg <= 0.5;
      const original = refAll.current.items.find(x => x.name === item.i)!;

      return {
        ...original,
        width: item.w,
        height: item.h,
        leftOffset: toLeft ? item.x : undefined,
        rightOffset: !toLeft ? refAll.current.cols.lg - (item.x + item.w) : undefined,
        topOffset: item.y,
      };
    });

    const sortedItems = [
      ...updatedItems.filter(x => x.name !== newItem.i),
      updatedItems.find(x => x.name === newItem.i)!,
    ];

    refAll.current.layouts = {
      lg: [...newItems.filter(x => x.i !== newItem.i), newItem],
    };

    onChange(sortedItems);
    setKey(x => x + 1);
  };

  useEffect(() => {
    refAll.current.items = [...items];
    setKey(x => x + 1);
  }, [items]);

  // TODO
  //  1. Unknown why but if we set layout and cols both instantly it not help...
  //  1.2 it means that we should make report... until we will send new key on window resize
  useEffect(() => {
    const updateItems = () => {
      if (!containerRef.current) {
        return;
      }

      const { width } = containerRef.current.getBoundingClientRect();
      const newColsCount = (width - (width % colSize)) / colSize;

      refAll.current.layouts = {
        lg: refAll.current.items.map(({ name, width, height, rightOffset, leftOffset, topOffset = 0 }) => {
          return {
            i: name,
            x: rightOffset != null ? newColsCount - width - rightOffset : leftOffset ?? 0,
            y: topOffset,
            w: width,
            h: height,
          };
        }),
      };
      refAll.current.cols = { lg: newColsCount, md: 0, sm: 0, xs: 0, xxs: 0 };
    };

    const updateContainerWidth = () => {
      if (!containerRef.current) {
        return;
      }

      const { width } = containerRef.current.getBoundingClientRect();

      refAll.current.containerWidth = width;
      const newColsCount = (width - (width % colSize)) / colSize;

      if (width <= 100 || refAll.current.cols.lg === newColsCount) {
        return false;
      }

      if (!refAll.current.isReady) {
        updateItems();
        setCallRerenderOfGrid(x => x + 1);
        refAll.current.isReady = true;
        return;
      }

      refAll.current.layouts = {
        lg: refAll.current.layouts.lg.map(lgEl => {
          const toLeft = (lgEl.x + lgEl.w / 2) / refAll.current.cols.lg <= 0.5;
          const next = {
            ...lgEl,
            x: toLeft ? lgEl.x : newColsCount - (refAll.current.cols.lg - lgEl.x),
          };
          return next;
        }),
      };

      refAll.current.cols = { lg: newColsCount, md: 0, sm: 0, xs: 0, xxs: 0 };
      setCallRerenderOfGrid(x => x + 1);
    };

    setTimeout(() => updateContainerWidth(), 100);

    const withRerender = () => {
      updateContainerWidth();
      setCallRerenderOfGrid(x => x + 1);
    };

    window.addEventListener('resize', withRerender);
    return () => {
      window.removeEventListener('resize', withRerender);
    };
  }, []);

  const isNotSet = initState.cols === refAll.current.cols.lg;

  return (
    <div ref={containerRef} className={clsx(classes.GridLayoutWrapper, 'relative p-4')}>
      {!isNotSet && isTabVisible && (
        <ResponsiveGridLayout
          key={callRerenderOfGrid}
          className={classes.GridLayout}
          layouts={refAll.current.layouts}
          breakpoints={refAll.current.breakpoints}
          cols={refAll.current.cols}
          rowHeight={30}
          width={refAll.current.containerWidth}
          preventCollision={true}
          compactType={null}
          allowOverlap
          onDragStop={onLayoutChange}
          onResizeStop={onLayoutChange}
          // onResizeStart={onLayoutChange}
          // onDragStart={onLayoutChange}
          isBounded
          containerPadding={[0, 0]}
          resizeHandles={['sw', 'se']}
          draggableHandle=".react-grid-dragHandleExample"
        >
          {refAll.current.items.map(x => (
            <div key={x.name} className="grid-item">
              {x.item()}
            </div>
          ))}
        </ResponsiveGridLayout>
      )}
    </div>
  );
};
