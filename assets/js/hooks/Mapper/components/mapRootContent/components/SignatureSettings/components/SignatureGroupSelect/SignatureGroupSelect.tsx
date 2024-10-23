import { Dropdown } from 'primereact/dropdown';
import clsx from 'clsx';
import { SignatureGroup, SystemSignature } from '@/hooks/Mapper/types';
import { renderIcon } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/renders';
import { Controller, useFormContext } from 'react-hook-form';

const signatureGroupOptions = Object.keys(SignatureGroup).map(x => ({
  value: SignatureGroup[x as keyof typeof SignatureGroup],
  label: SignatureGroup[x as keyof typeof SignatureGroup],
}));

// @ts-ignore
const renderSignatureTemplate = option => {
  if (!option) {
    return 'No group selected';
  }

  return (
    <div className="flex gap-2 items-center">
      <span className="w-[20px] mt-[1px] flex justify-center items-center">
        {renderIcon(
          { group: option.label } as SystemSignature,
          option.label === SignatureGroup.CosmicSignature ? { w: 10, h: 10 } : { w: 16, h: 16 },
        )}
      </span>
      <span>{option.label}</span>
    </div>
  );
};

export interface SignatureGroupSelectProps {
  name: string;
  defaultValue?: string;
}

export const SignatureGroupSelect = ({ name, defaultValue = '' }: SignatureGroupSelectProps) => {
  const { control } = useFormContext();
  return (
    <Controller
      name={name}
      control={control}
      defaultValue={defaultValue}
      render={({ field }) => (
        <Dropdown
          value={field.value}
          onChange={field.onChange}
          options={signatureGroupOptions}
          optionLabel="label"
          optionValue="value"
          placeholder="Select group"
          className={clsx('w-full')}
          scrollHeight="240px"
          itemTemplate={renderSignatureTemplate}
          valueTemplate={renderSignatureTemplate}
        />
      )}
    />
  );
};
