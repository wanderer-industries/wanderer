import React from 'react';

import classes from './Widget.module.scss';
import clsx from 'clsx';

export interface WidgetProps {
  label: React.ReactNode | string;
  windowId?: string;
  children?: React.ReactNode;
}

export const Widget = ({ label, children, windowId }: WidgetProps) => {
  return (
    <div
      data-window-id={windowId}
      className={clsx(
        classes.root,
        'flex flex-col w-full h-full rounded',
        'text-gray-200 shadow-lg',
        'border border-gray-500 border-opacity-30',
        'bg-opacity-80 bg-neutral-900 ',
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
        className={clsx(classes.Content, 'overflow-auto', 'bg-opacity-5  custom-scrollbar')}
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
