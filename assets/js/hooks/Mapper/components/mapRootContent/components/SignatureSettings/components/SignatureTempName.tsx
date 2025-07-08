import { Controller, useFormContext } from 'react-hook-form';
import { InputText } from 'primereact/inputtext';
import { SystemSignature } from '@/hooks/Mapper/types';

export const SignatureTempName = () => {
  const { control } = useFormContext<SystemSignature>();

  return (
    <Controller
      name="temporary_name"
      control={control}
      render={({ field }) => <InputText placeholder="Temporary Name" value={field.value} onChange={field.onChange} />}
    />
  );
};
