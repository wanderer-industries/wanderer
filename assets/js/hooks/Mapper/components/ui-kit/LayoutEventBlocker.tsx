import { MouseEvent } from 'react';
import { WithChildren, WithClassName } from '@/hooks/Mapper/types/common.ts';

const preventMousedownFunc = (e: MouseEvent) => {
  e.preventDefault();
  e.stopPropagation();
};

// TODO this components need for preventing events on headers of widgets
//      otherwise on mousedown to btn window will moving...
export const LayoutEventBlocker = ({ children, className }: WithChildren & WithClassName) => {
  return (
    <div onMouseDown={preventMousedownFunc} className={className}>
      {children}
    </div>
  );
};
