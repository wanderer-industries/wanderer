import classes from './WdImgButton.module.scss';
import clsx from 'clsx';
import { WithClassName } from '@/hooks/Mapper/types/common.ts';
import { HTMLProps, MouseEvent } from 'react';
import { WdTooltipWrapper, WdTooltipWrapperProps } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';

export enum WdImageSize {
  off = 'off',
  small = 'small',
  normal = 'normal',
  large = 'large',
}

export type WdImgButtonTooltip = Pick<WdTooltipWrapperProps, 'content' | 'position' | 'offset' | 'className'>;

export type WdImgButtonProps = {
  onClick?(e: MouseEvent): void;
  source?: string;
  width?: number;
  height?: number;
  tooltip?: WdImgButtonTooltip;
  textSize?: WdImageSize;
} & WithClassName &
  HTMLProps<HTMLDivElement>;

export const WdImgButton = ({
  onClick,
  className,
  source,
  width = 20,
  height = 20,
  textSize = WdImageSize.normal,
  tooltip,
  disabled,
  ...props
}: WdImgButtonProps) => {
  const content = (
    <div
      {...props}
      className={clsx(
        classes.WdImgButtonRoot,
        {
          [classes.Normal]: textSize === WdImageSize.normal,
          [classes.Large]: textSize === WdImageSize.large,
          [classes.Disabled]: disabled,
        },
        'pi cursor-pointer',
        className,
      )}
      onClick={disabled ? undefined : onClick}
    >
      {source && <img src={source} width={width} height={height} className="external-icon" />}
    </div>
  );

  if (tooltip) {
    return <WdTooltipWrapper {...tooltip}>{content}</WdTooltipWrapper>;
  }

  return content;
};
