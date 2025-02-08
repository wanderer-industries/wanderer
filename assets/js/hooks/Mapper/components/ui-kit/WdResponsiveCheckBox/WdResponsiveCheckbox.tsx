import React from 'react';
import clsx from 'clsx';
import { WdCheckbox, WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit';

/**
 * Display modes for the responsive checkbox.
 *
 * - "full": show the full label (e.g. "Show offline" or "Show ship name")
 * - "abbr": show the abbreviated label (e.g. "Offline" or "Ship name")
 * - "checkbox": show only the checkbox (no text)
 * - "hide": do not render the checkbox at all
 */
export type WdDisplayMode = 'full' | 'abbr' | 'checkbox' | 'hide';

export interface WdResponsiveCheckboxProps {
  tooltipContent: string;
  size: 'xs' | 'normal' | 'm';
  labelFull: string;
  labelAbbreviated: string;
  value: boolean;
  onChange: () => void;
  classNameLabel?: string;
  containerClassName?: string;
  labelSide?: 'left' | 'right';
  displayMode: WdDisplayMode;
}

export const WdResponsiveCheckbox: React.FC<WdResponsiveCheckboxProps> = ({
  tooltipContent,
  size,
  labelFull,
  labelAbbreviated,
  value,
  onChange,
  classNameLabel,
  containerClassName,
  labelSide = 'left',
  displayMode,
}) => {
  if (displayMode === 'hide') {
    return null;
  }

  const label =
    displayMode === 'full'
      ? labelFull
      : displayMode === 'abbr'
        ? labelAbbreviated
        : displayMode === 'checkbox'
          ? ''
          : labelFull;

  const checkbox = (
    <div className={clsx('min-w-0', containerClassName)}>
      <WdCheckbox
        size={size}
        labelSide={labelSide}
        label={label}
        value={value}
        classNameLabel={classNameLabel}
        onChange={onChange}
      />
    </div>
  );

  return tooltipContent ? <WdTooltipWrapper content={tooltipContent}>{checkbox}</WdTooltipWrapper> : checkbox;
};
