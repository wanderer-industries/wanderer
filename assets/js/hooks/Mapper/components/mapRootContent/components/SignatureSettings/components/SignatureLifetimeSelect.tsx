import { Controller, useFormContext } from 'react-hook-form';
import { SystemSignature } from '@/hooks/Mapper/types';
import { WdLifetimeSelector } from '@/hooks/Mapper/components/ui-kit/WdLifetimeSelector.tsx';

export interface SignatureEOLCheckboxProps {
  name: string;
  defaultValue?: boolean;
}

export const SignatureLifetimeSelect = ({ name, defaultValue = false }: SignatureEOLCheckboxProps) => {
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
          return <WdLifetimeSelector lifetime={field.value} onChangeLifetime={e => field.onChange(e)} />;
        }}
      />
    </div>
  );
};
