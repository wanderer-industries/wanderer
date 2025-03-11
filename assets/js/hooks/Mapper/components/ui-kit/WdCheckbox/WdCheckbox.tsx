import classes from './WdCheckbox.module.scss';
import { Checkbox, CheckboxChangeEvent } from 'primereact/checkbox';
import { WithClassName } from '@/hooks/Mapper/types/common';
import clsx from 'clsx';
import React, { useMemo } from 'react';

let counter = 0;

export interface WdCheckboxProps {
  id?: string;
  label: React.ReactNode | string;
  classNameLabel?: string;
  value: boolean;
  labelSide?: 'left' | 'right';
  onChange?: (event: CheckboxChangeEvent) => void;
  size?: 'xs' | 'm' | 'normal';
}

export const WdCheckbox = ({
  id: defaultId,
  label,
  className,
  classNameLabel,
  value,
  onChange,
  labelSide = 'right',
  size = 'normal',
}: WdCheckboxProps & WithClassName) => {
  const id = useMemo(() => defaultId || (++counter).toString(), [defaultId]);

  const labelElement = (
    <label
      htmlFor={id}
      className={clsx(
        classes.Label,
        'select-none',
        {
          ['ml-1']: labelSide === 'right' && size === 'xs',
          ['mr-1']: labelSide === 'left' && size === 'xs',
          ['ml-1.5']: labelSide === 'right' && (size === 'normal' || size === 'm'),
          ['mr-1.5']: labelSide === 'left' && (size === 'normal' || size === 'm'),
        },
        classNameLabel,
      )}
    >
      {label}
    </label>
  );

  return (
    <div className={clsx(className, 'flex items-center')}>
      {labelSide === 'left' && labelElement}
      <Checkbox
        inputId={id}
        className={clsx(classes.CheckboxRoot, {
          [classes.SizeNormal]: size === 'normal',
          [classes.SizeM]: size === 'm',
          [classes.SizeXS]: size === 'xs',
        })}
        onChange={onChange}
        checked={value}
      />
      {labelSide === 'right' && labelElement}
    </div>
  );
};
