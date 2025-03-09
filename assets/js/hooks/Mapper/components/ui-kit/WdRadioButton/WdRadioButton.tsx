import React from 'react';
import clsx from 'clsx';
import styles from './WdRadioButton.module.scss';

export interface WdRadioButtonProps {
  id: string;
  name: string;
  checked: boolean;
  onChange: (event: React.ChangeEvent<HTMLInputElement>) => void;
  label?: string;
  className?: string;
  disabled?: boolean;
}

const WdRadioButton: React.FC<WdRadioButtonProps> = ({
  id,
  name,
  checked,
  onChange,
  label,
  className,
  disabled = false,
}) => {
  return (
    <div className={clsx('flex items-center', className)}>
      <input
        id={id}
        type="radio"
        name={name}
        checked={checked}
        onChange={onChange}
        disabled={disabled}
        className={clsx(
          styles.RadioInput,
          'w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600',
        )}
      />
      {label && (
        <label
          htmlFor={id}
          className="ml-2 text-sm font-medium text-gray-900 dark:text-gray-300 cursor-pointer"
        >
          {label}
        </label>
      )}
    </div>
  );
};

export default WdRadioButton; 