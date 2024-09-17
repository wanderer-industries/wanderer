import { SignatureGroup, SystemSignature } from '@/hooks/Mapper/types';
import { renderIcon } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/renders';

export interface SignatureViewProps {}

export const SignatureView = (sig: SignatureViewProps & SystemSignature) => {
  return (
    <div className="flex gap-2 items-center">
      {renderIcon(sig)}
      <div>{sig?.eve_id}</div>
      <div>{sig?.group ?? SignatureGroup.CosmicSignature}</div>
      <div>{sig?.name}</div>
    </div>
  );
};
