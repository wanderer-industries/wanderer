import { WHClassView } from '@/hooks/Mapper/components/ui-kit';
import { DestinationType } from '@/hooks/Mapper/constants.ts';

const renderNoValue = () => <div className="flex gap-2 items-center">-Unknown-</div>;

export const renderDestinationType = (option: DestinationType) => {
  if (!option) {
    return renderNoValue();
  }

  const { value, whClassName = '' } = option;
  if (value == null) {
    return renderNoValue();
  }

  if (['c1_c2_c3', 'c4_c5'].includes(value)) {
    const arr = whClassName.split('_');

    return (
      <div className="flex gap-1 items-center">
        {arr.map(x => (
          <WHClassView
            key={x}
            classNameWh="!text-[11px] !font-bold"
            hideWhClassName
            hideTooltip
            whClassName={x}
            noOffset
            useShortTitle
          />
        ))}
      </div>
    );
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
