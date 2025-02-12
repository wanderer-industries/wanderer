import React from 'react';
import { VirtualScroller, VirtualScrollerTemplateOptions } from 'primereact/virtualscroller';
import clsx from 'clsx';
import { CharItemProps } from './types';

export type LocalCharactersListProps = {
  items: Array<CharItemProps>;
  itemSize: number;
  itemTemplate: (char: CharItemProps, options: VirtualScrollerTemplateOptions) => React.ReactNode;
  containerClassName?: string;
  style?: React.CSSProperties;
  autoSize?: boolean;
};

export const LocalCharactersList = ({
  items,
  itemSize,
  itemTemplate,
  containerClassName,
  style = {},
  autoSize = false,
}: LocalCharactersListProps) => {
  const computedHeight = autoSize ? `${Math.max(items.length, 1) * itemSize}px` : style.height || '100%';

  const localStyle: React.CSSProperties = {
    ...style,
    height: computedHeight,
    width: '100%',
    boxSizing: 'border-box',
    overflowX: 'hidden',
  };

  return (
    <VirtualScroller
      items={items}
      itemSize={itemSize}
      orientation="vertical"
      className={clsx('w-full h-full', containerClassName)}
      itemTemplate={itemTemplate}
      autoSize={autoSize}
      style={localStyle}
    />
  );
};
