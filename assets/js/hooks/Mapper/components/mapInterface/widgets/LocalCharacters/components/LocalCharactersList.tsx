import React from 'react';
import { VirtualScroller, VirtualScrollerTemplateOptions } from 'primereact/virtualscroller';
import clsx from 'clsx';
import { CharItemProps } from './types';

type LocalCharactersListProps = {
  items: Array<CharItemProps>;
  itemSize: number;
  itemTemplate: (char: CharItemProps, options: VirtualScrollerTemplateOptions) => React.ReactNode;
  containerClassName?: string;
};

export const LocalCharactersList = ({
  items,
  itemSize,
  itemTemplate,
  containerClassName,
}: LocalCharactersListProps) => {
  return (
    <VirtualScroller
      items={items}
      itemSize={itemSize}
      orientation="vertical"
      className={clsx('w-full h-full', containerClassName)}
      itemTemplate={itemTemplate}
    />
  );
};
