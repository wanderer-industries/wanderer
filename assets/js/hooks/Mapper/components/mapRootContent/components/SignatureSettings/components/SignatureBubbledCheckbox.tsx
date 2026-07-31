import { Controller, useFormContext } from 'react-hook-form';
import { Checkbox } from 'primereact/checkbox';
import { SystemSignature } from '@/hooks/Mapper/types';

export interface SignatureBubbledCheckboxProps {
  name: string;
}

export const SignatureBubbledCheckbox = ({ name }: SignatureBubbledCheckboxProps) => {
  const { control } = useFormContext<SystemSignature>();

  return (
    <div className="my-1 flex items-center gap-2">
      <Controller
        // @ts-ignore
        name={name}
        control={control}
        defaultValue={false}
        render={({ field }) => (
          <Checkbox
            inputId={name}
            checked={!!field.value}
            onChange={e => field.onChange(e.checked)}
          />
        )}
      />
      <label htmlFor={name} className="text-stone-400 text-[12px] select-none">
        Hole is inside a bubble
      </label>
    </div>
  );
};
