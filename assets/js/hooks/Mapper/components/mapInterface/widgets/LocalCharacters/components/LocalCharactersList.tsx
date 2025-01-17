import React from 'react';
import { VirtualScroller, VirtualScrollerTemplateOptions } from 'primereact/virtualscroller';
import clsx from 'clsx';
import { CharItemProps } from './types';
import classes from './LocalCharacterList.module.scss';

type LocalCharactersListProps = {
  items: Array<CharItemProps>;

  itemSize: number;

  itemTemplate: (char: CharItemProps, options: VirtualScrollerTemplateOptions) => React.ReactNode;

  containerClassName?: string;
};

export function LocalCharactersList({ items, itemSize, itemTemplate, containerClassName }: LocalCharactersListProps) {
  return (
    <VirtualScroller
      items={items}
      itemSize={itemSize}
      itemTemplate={itemTemplate}
      className={clsx(classes.VirtualScroller, containerClassName)}
      autoSize={false}
    />
  );
}
