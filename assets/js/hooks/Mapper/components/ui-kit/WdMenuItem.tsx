import { WithChildren, WithClassName } from '@/hooks/Mapper/types/common.ts';
import clsx from 'clsx';

type WdMenuItemProps = { icon?: string; disabled?: boolean } & WithChildren & WithClassName;
export const WdMenuItem = ({ children, icon, disabled, className }: WdMenuItemProps) => {
  return (
    <a
      className={clsx(
        'flex gap-[6px] w-full h-full items-center px-[12px] !py-0',
        'p-menuitem-link',
        {
          'p-disabled': disabled,
        },
        className,
      )}
    >
      {icon && <div className={clsx('min-w-[20px]', icon)}></div>}
      <div className="w-full">{children}</div>
    </a>
  );
};
