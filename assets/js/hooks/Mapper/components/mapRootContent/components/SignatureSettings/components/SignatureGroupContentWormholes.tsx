import { useFormContext } from 'react-hook-form';
import { SystemSignature } from '@/hooks/Mapper/types';
import { SignatureWormholeTypeSelect } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/components/SignatureWormholeTypeSelect';
import { SignatureK162TypeSelect } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/components/SignatureK162TypeSelect';
import { SignatureLeadsToSelect } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/components/SignatureLeadsToSelect';
import { SignatureLifetimeSelect } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/components/SignatureLifetimeSelect.tsx';
import { SignatureTempName } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/components/SignatureTempName.tsx';

export const SignatureGroupContentWormholes = () => {
  const { watch } = useFormContext<SystemSignature>();
  const type = watch('type');

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

      <div className="grid grid-cols-[100px_250px_1fr] gap-2 items-center text-[14px]">
        <span>Lifetime:</span>
        <SignatureLifetimeSelect name="time_status" />
      </div>

      <label className="grid grid-cols-[100px_250px_1fr] gap-2 items-center text-[14px]">
        <span>Temp. Name:</span>
        <SignatureTempName />
      </label>
    </>
  );
};
