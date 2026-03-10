import { Controller, useFormContext } from 'react-hook-form';
import { MassState, SystemSignature } from '@/hooks/Mapper/types';
import { WdMassStatusSelector } from '@/hooks/Mapper/components/ui-kit/WdMassStatusSelector.tsx';

export interface SignatureMassStatusSelectProps {
  name: string;
  defaultValue?: MassState;
}

export const SignatureMassStatusSelect = ({
  name,
  defaultValue = MassState.normal,
}: SignatureMassStatusSelectProps) => {
  const { control } = useFormContext<SystemSignature>();

  return (
    <div className="my-1">
      <Controller
        // @ts-ignore
        name={name}
        control={control}
        defaultValue={defaultValue}
        render={({ field }) => {
          // @ts-ignore
          return <WdMassStatusSelector massStatus={field.value} onChangeMassStatus={e => field.onChange(e)} />;
        }}
      />
    </div>
  );
};
