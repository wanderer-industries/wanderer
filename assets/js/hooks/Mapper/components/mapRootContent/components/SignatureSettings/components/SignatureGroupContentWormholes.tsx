import { Controller, useFormContext } from 'react-hook-form';
import { SystemSignature } from '@/hooks/Mapper/types';
import { SignatureWormholeTypeSelect } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/components/SignatureWormholeTypeSelect';
import { SignatureK162TypeSelect } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/components/SignatureK162TypeSelect';
import { SignatureLeadsToSelect } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/components/SignatureLeadsToSelect';
import { SignatureEOLCheckbox } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/components/SignatureEOLCheckbox';
import { InputText } from 'primereact/inputtext';
import { useMapGetOption } from '@/hooks/Mapper/mapRootProvider/hooks/api/useMapGetOption';

export const SignatureGroupContentWormholes = () => {
  const { watch, control } = useFormContext<SystemSignature>();
  const type = watch('type');
  const isTempSystemNameEnabled = useMapGetOption('show_temp_system_name') === 'true';

  return (
    <>
      <label className="grid grid-cols-[100px_250px_1fr] gap-2 items-center text-[14px]">
        <span>Type:</span>
        <SignatureWormholeTypeSelect name="type" />
      </label>

      {type === 'K162' && (
        <label className="grid grid-cols-[100px_250px_1fr] gap-2 items-center text-[14px]">
          <span>K162 Type:</span>
          <SignatureK162TypeSelect name="k162Type" />
        </label>
      )}

      <label className="grid grid-cols-[100px_250px_1fr] gap-2 items-center text-[14px]">
        <span>Leads To:</span>
        <SignatureLeadsToSelect name="linked_system" />
      </label>

      <label className="grid grid-cols-[100px_250px_1fr] gap-2 items-center text-[14px]">
        <span>EOL:</span>
        <SignatureEOLCheckbox name="isEOL" />
      </label>

      {isTempSystemNameEnabled && (
        <label className="grid grid-cols-[100px_250px_1fr] gap-2 items-center text-[14px]">
          <span>Temporary Name:</span>
          <Controller
            name="temp_name"
            control={control}
            render={({ field }) => (
              <InputText placeholder="Temporary Name" value={field.value} onChange={field.onChange} />
            )}
          />
        </label>
      )}
    </>
  );
};
