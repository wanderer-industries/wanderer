import { ReactNode } from 'react';
import { WithChildren } from '@/hooks/Mapper/types/common.ts';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { TooltipPosition } from '@/hooks/Mapper/components/ui-kit/WdTooltip';
import clsx from 'clsx';

type MenuItemWithInfoProps = {
  infoTitle: ReactNode;
  infoClass?: string;
  tooltipWrapperClassName?: string;
} & WithChildren;
export const MenuItemWithInfo = ({
  children,
  infoClass,
  infoTitle,
  tooltipWrapperClassName,
}: MenuItemWithInfoProps) => {
  return (
    <div className="flex justify-between w-full h-full items-center">
      {children}
      <WdTooltipWrapper
        content={infoTitle}
        position={TooltipPosition.top}
        className="!opacity-100 !pointer-events-auto"
        wrapperClassName={tooltipWrapperClassName}
      >
        <div className={clsx('pi text-orange-400', infoClass)} />
      </WdTooltipWrapper>
    </div>
  );
};
