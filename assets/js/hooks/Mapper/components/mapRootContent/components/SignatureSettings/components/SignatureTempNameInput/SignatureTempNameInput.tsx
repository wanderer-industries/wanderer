import { Controller, useFormContext } from 'react-hook-form';
import { SystemSignature } from '@/hooks/Mapper/types';
import { InputText } from 'primereact/inputtext';
import { MAX_TEMP_NAME_LENGTH } from '@/hooks/Mapper/constants.ts';

export interface SignatureTempNameInputProps {
  name: string;
  defaultValue?: string;
}

export const SignatureTempNameInput = ({ name, defaultValue = '' }: SignatureTempNameInputProps) => {
  const { control } = useFormContext<SystemSignature>();

  return (
    <Controller
      // @ts-ignore
      name={name}
      control={control}
      defaultValue={defaultValue}
      render={({ field }) => (
        <InputText
          placeholder="Temporary Name"
          // @ts-ignore
          value={field.value}
          maxLength={MAX_TEMP_NAME_LENGTH}
          onChange={field.onChange}
        />
      )}
    />
  );
};
