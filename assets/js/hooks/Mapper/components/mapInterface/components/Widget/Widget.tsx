import React from 'react';

import classes from './Widget.module.scss';
import clsx from 'clsx';
import { WithChildren } from '@/hooks/Mapper/types/common.ts';

export type WidgetProps = {
  label: React.ReactNode | string;
  windowId?: string;
  contentClassName?: string;
} & WithChildren;

export const Widget = ({ label, children, windowId, contentClassName }: WidgetProps) => {
  return (
    <div
      data-window-id={windowId}
      className={clsx(
        classes.root,
        'flex flex-col w-full h-full rounded',
        'text-gray-200 shadow-lg',
        'border border-gray-500 border-opacity-30',
        // the map shows through the widget, so blur what is behind it to keep the content readable
        'bg-opacity-70 bg-neutral-900 backdrop-blur-md',
      )}
    >
      <div
        className={clsx(
          classes.Header,
          'react-grid-dragHandleExample h-7 text-sm flex w-full',
          'bg-gray-400 bg-opacity-5 ',
          'px-2 py-1',
          'border-b border-gray-500 border-opacity-30',
          'cursor-move select-none ',
        )}
      >
        {label}
      </div>
      <div
        className={clsx(classes.Content, 'overflow-auto', 'bg-opacity-5 custom-scrollbar', contentClassName)}
        style={{ flexGrow: 1 }}
        onContextMenu={e => {
          e.preventDefault();
          e.stopPropagation();
        }}
      >
        {children}
      </div>
    </div>
  );
};
