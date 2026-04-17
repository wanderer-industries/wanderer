import { useFormContext } from 'react-hook-form';
import { SystemSignature } from '@/hooks/Mapper/types';
import { SignatureWormholeTypeSelect } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/components/SignatureWormholeTypeSelect';
import { SignatureDestinationTypeSelect } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/components/SignatureDestinationTypeSelect';
import { SignatureLeadsToSelect } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/components/SignatureLeadsToSelect';
import { SignatureLifetimeSelect } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/components/SignatureLifetimeSelect.tsx';
import { SignatureTempName } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/components/SignatureTempName.tsx';
import { SignatureMassStatusSelect } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/components/SignatureMassStatusSelect.tsx';
import { MULTI_DEST_WHS } from '@/hooks/Mapper/constants';

export const SignatureGroupContentWormholes = () => {
  const { watch } = useFormContext<SystemSignature>();
  const type = watch('type');

  return (
    <>
      <label className="grid grid-cols-[100px_250px_1fr] gap-2 items-center text-[14px]">
        <span>Type:</span>
        <SignatureWormholeTypeSelect name="type" />
      </label>

      {MULTI_DEST_WHS.includes(type) && (
        <label className="grid grid-cols-[100px_250px_1fr] gap-2 items-center text-[14px]">
          <span>Destination Class:</span>
          <SignatureDestinationTypeSelect name="destType" type={type} />
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

      <div className="grid grid-cols-[100px_250px_1fr] gap-2 items-center text-[14px]">
        <span>Mass status:</span>
        <SignatureMassStatusSelect name="mass_status" />
      </div>

      <label className="grid grid-cols-[100px_250px_1fr] gap-2 items-center text-[14px]">
        <span>Temp. Name:</span>
        <SignatureTempName />
      </label>
    </>
  );
};
