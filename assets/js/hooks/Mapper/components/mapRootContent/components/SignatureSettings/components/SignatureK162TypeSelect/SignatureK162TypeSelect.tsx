import { Dropdown } from 'primereact/dropdown';
import clsx from 'clsx';
import { Controller, useFormContext } from 'react-hook-form';
import { useMemo } from 'react';
import { SystemSignature } from '@/hooks/Mapper/types';
import { WHClassView } from '@/hooks/Mapper/components/ui-kit';

export const k162Types = [
  {
    label: 'Hi-Sec',
    value: 'hs',
    whClassName: 'A641',
  },
  {
    label: 'Low-Sec',
    value: 'ls',
    whClassName: 'J377',
  },
  {
    label: 'Null-Sec',
    value: 'ns',
    whClassName: 'C248',
  },
  {
    label: 'C1',
    value: 'c1',
    whClassName: 'E004',
  },
  {
    label: 'C2',
    value: 'c2',
    whClassName: 'D382',
  },
  {
    label: 'C3',
    value: 'c3',
    whClassName: 'L477',
  },
  {
    label: 'C4',
    value: 'c4',
    whClassName: 'M001',
  },
  {
    label: 'C5',
    value: 'c5',
    whClassName: 'L614',
  },
  {
    label: 'C6',
    value: 'c6',
    whClassName: 'G008',
  },
  {
    label: 'C13',
    value: 'c13',
    whClassName: 'A009',
  },
  {
    label: 'Thera',
    value: 'thera',
    whClassName: 'F353',
  },
  {
    label: 'Pochven',
    value: 'pochven',
    whClassName: 'F216',
  },
];

const renderNoValue = () => <div className="flex gap-2 items-center">-Unknown-</div>;

// @ts-ignore
export const renderK162Type = (option: {
  label?: string;
  value: string;
  security?: string;
  system_class?: number;
  whClassName?: string;
}) => {
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

export interface SignatureK162TypeSelectProps {
  name: string;
  defaultValue?: string;
}

export const SignatureK162TypeSelect = ({ name, defaultValue = '' }: SignatureK162TypeSelectProps) => {
  const { control } = useFormContext<SystemSignature>();

  const options = useMemo(() => {
    return [{ value: null }, ...k162Types];
  }, []);

  return (
    <Controller
      // @ts-ignore
      name={name}
      control={control}
      defaultValue={defaultValue}
      render={({ field }) => {
        return (
          <Dropdown
            value={field.value}
            onChange={field.onChange}
            options={options}
            optionValue="value"
            placeholder="Select K162 type"
            className={clsx('w-full')}
            scrollHeight="240px"
            itemTemplate={renderK162Type}
            valueTemplate={renderK162Type}
          />
        );
      }}
    />
  );
};
