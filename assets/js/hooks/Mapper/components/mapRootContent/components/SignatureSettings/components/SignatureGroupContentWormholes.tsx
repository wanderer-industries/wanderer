import { SignatureWormholeTypeSelect } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/components/SignatureWormholeTypeSelect';
import { SignatureLeadsToSelect } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/components/SignatureLeadsToSelect';

export const SignatureGroupContentWormholes = () => {
  return (
    <>
      <label className="grid grid-cols-[100px_250px_1fr] gap-2 items-center text-[14px]">
        <span>Type:</span>
        <SignatureWormholeTypeSelect name="type" />
      </label>

      <label className="grid grid-cols-[100px_250px_1fr] gap-2 items-center text-[14px]">
        <span>Leads To:</span>
        <SignatureLeadsToSelect name="linked_system" />
      </label>
    </>
  );
};
