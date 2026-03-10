import { LayoutEventBlocker } from '@/hooks/Mapper/components/ui-kit';
import { WdShipSizeSelector, WdShipSizeSelectorProps } from '@/hooks/Mapper/components/ui-kit/WdShipSizeSelector.tsx';

export const ShipSizeActionsWrapper = (props: WdShipSizeSelectorProps) => {
  return (
    <LayoutEventBlocker className="flex flex-col gap-1 w-[100%] h-full px-2 pt-[4px]">
      <div className="text-[12px] text-stone-500 font-semibold">Ship size:</div>

      <WdShipSizeSelector {...props} />
    </LayoutEventBlocker>
  );
};
