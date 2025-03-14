import classes from './InfoDrawer.module.scss';
import { WithChildren, WithClassName, WithHTMLProps } from '@/hooks/Mapper/types/common.ts';
import clsx from 'clsx';
import React from 'react';

export type InfoDrawerProps = { title?: React.ReactNode; labelClassName?: string; rightSide?: boolean } & WithChildren &
  WithClassName &
  Omit<WithHTMLProps, 'title'>;

export const InfoDrawer = ({
  title,
  children,
  className,
  labelClassName,
  rightSide,
  ...htmlProps
}: InfoDrawerProps) => {
  return (
    <div
      className={clsx(classes.InfoDrawerRoot, 'text-xs pl-1', className, {
        [classes.RightSide]: rightSide,
        'flex flex-col items-end pr-1': rightSide,
        'pl-1': !rightSide,
      })}
      {...htmlProps}
    >
      {title && <div className={clsx(classes.InfoDrawerLabel, 'text-neutral-400', labelClassName)}>{title}</div>}
      <div>{children}</div>
    </div>
  );
};
