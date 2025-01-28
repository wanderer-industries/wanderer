import { WHClassView } from '@/hooks/Mapper/components/ui-kit';
import { K162Type } from '@/hooks/Mapper/constants.ts';

const renderNoValue = () => <div className="flex gap-2 items-center">-Unknown-</div>;

export const renderK162Type = (option: K162Type) => {
  if (!option) {
    return renderNoValue();
  }

  const { value, whClassName = '' } = option;
  if (value == null) {
    return renderNoValue();
  }

  return (
    <WHClassView
      classNameWh="!text-[11px] !font-bold"
      hideWhClassName
      hideTooltip
      whClassName={whClassName}
      noOffset
      useShortTitle
    />
  );
};
