import { Dropdown } from 'primereact/dropdown';
import clsx from 'clsx';
import { Controller, useFormContext } from 'react-hook-form';
import { useMemo } from 'react';
import { SystemSignature } from '@/hooks/Mapper/types';
import { renderDestinationType } from '.';
import { DEST_TYPES_MAP } from '@/hooks/Mapper/constants';

export interface SignatureDestinationTypeSelectProps {
  name: string;
  type: string;
  defaultValue?: string;
}

export const SignatureDestinationTypeSelect = ({
  name,
  type: whType,
  defaultValue = '',
}: SignatureDestinationTypeSelectProps) => {
  const { control } = useFormContext<SystemSignature>();

  const options = useMemo(() => {
    return [{ value: null }, ...DEST_TYPES_MAP[whType]];
  }, [whType]);

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
            placeholder="Select destination"
            className={clsx('w-full')}
            scrollHeight="240px"
            itemTemplate={renderDestinationType}
            valueTemplate={renderDestinationType}
          />
        );
      }}
    />
  );
};
