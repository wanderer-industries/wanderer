import { LayoutEventBlocker } from '@/hooks/Mapper/components/ui-kit';
import { WdLifetimeSelector, WdLifetimeSelectorProps } from '@/hooks/Mapper/components/ui-kit/WdLifetimeSelector.tsx';

export const LifetimeActionsWrapper = (props: WdLifetimeSelectorProps) => {
  return (
    <LayoutEventBlocker className="flex flex-col gap-1 w-[100%] h-full px-2 pt-[4px]">
      <div className="text-[12px] text-stone-500 font-semibold">Life time:</div>

      <WdLifetimeSelector {...props} />
    </LayoutEventBlocker>
  );
};
