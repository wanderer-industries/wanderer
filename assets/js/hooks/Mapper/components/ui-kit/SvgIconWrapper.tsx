import React from 'react';
import clsx from 'clsx';

export type SvgIconProps = React.SVGAttributes<SVGElement> & {
  width?: number;
  height?: number;
  className?: string;
};

export const SvgIconWrapper = ({
  width = 24,
  height = 24,
  children,
  className,
  ...props
}: SvgIconProps & { children: React.ReactNode }) => {
  return (
    <svg
      width={width}
      height={height}
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={clsx('w-[19px] h-[19px]', className)}
      {...props}
    >
      {children}
    </svg>
  );
};
