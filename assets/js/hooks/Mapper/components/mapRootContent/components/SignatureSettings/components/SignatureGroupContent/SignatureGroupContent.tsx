import { Controller, useFormContext } from 'react-hook-form';
import { SignatureGroup, SystemSignature } from '@/hooks/Mapper/types';
import { useSystemsSettingsProvider } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/Provider.tsx';
import { SignatureGroupContentWormholes } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/components/SignatureGroupContentWormholes.tsx';
import { InputText } from 'primereact/inputtext';

export interface SignatureGroupContentProps {}

export const SignatureGroupContent = ({}: SignatureGroupContentProps) => {
  const { watch, control } = useFormContext<SystemSignature>();
  const group = watch('group');

  const {
    value: { systemId },
  } = useSystemsSettingsProvider();

  if (!systemId) {
    return null;
  }

  if (group === SignatureGroup.Wormhole) {
    return (
      <>
        <SignatureGroupContentWormholes />
      </>
    );
  }

  if (group === SignatureGroup.CosmicSignature) {
    return <div></div>;
  }

  return (
    <div>
      <label className="grid grid-cols-[100px_250px_1fr] gap-2 items-center text-[14px]">
        <span>Name:</span>
        <Controller
          name="name"
          control={control}
          render={({ field }) => <InputText placeholder="Name" value={field.value} onChange={field.onChange} />}
        />
      </label>
    </div>
  );
};
