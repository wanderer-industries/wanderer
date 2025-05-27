import { WithChildren } from '@/hooks/Mapper/types/common.ts';
import clsx from 'clsx';

type WdMenuItemProps = { icon?: string; disabled?: boolean } & WithChildren;
export const WdMenuItem = ({ children, icon, disabled }: WdMenuItemProps) => {
  return (
    <a
      className={clsx('flex gap-[6px] w-full h-full items-center px-[12px] !py-0 ml-[-2px]', 'p-menuitem-link', {
        'p-disabled': disabled,
      })}
    >
      {icon && <div className={clsx('min-w-[20px]', icon)}></div>}
      <div className="w-full">{children}</div>
    </a>
  );
};
