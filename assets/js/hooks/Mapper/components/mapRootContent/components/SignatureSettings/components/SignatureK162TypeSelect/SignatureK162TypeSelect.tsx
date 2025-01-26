import { Dropdown } from 'primereact/dropdown';
import clsx from 'clsx';
import { Controller, useFormContext } from 'react-hook-form';
import { useMemo } from 'react';
import { SystemSignature } from '@/hooks/Mapper/types';
import { K162_TYPES } from '@/hooks/Mapper/constants.ts';
import { renderK162Type } from '.';

export interface SignatureK162TypeSelectProps {
  name: string;
  defaultValue?: string;
}

export const SignatureK162TypeSelect = ({ name, defaultValue = '' }: SignatureK162TypeSelectProps) => {
  const { control } = useFormContext<SystemSignature>();

  const options = useMemo(() => {
    return [{ value: null }, ...K162_TYPES];
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
