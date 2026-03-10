import { LayoutEventBlocker } from '@/hooks/Mapper/components/ui-kit';
import {
  WdMassStatusSelector,
  WdMassStatusSelectorProps,
} from '@/hooks/Mapper/components/ui-kit/WdMassStatusSelector.tsx';

export const MassStatusActionsWrapper = (props: WdMassStatusSelectorProps) => {
  return (
    <LayoutEventBlocker className="flex flex-col gap-1 w-[100%] h-full px-2 pt-[4px]">
      <div className="text-[12px] text-stone-500 font-semibold">Mass status:</div>

      <WdMassStatusSelector {...props} />
    </LayoutEventBlocker>
  );
};
