import { GroupType, SignatureGroup, SystemSignature } from '@/hooks/Mapper/types';
import { GROUPS } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/constants.ts';

export const renderIcon = (row: SystemSignature, customSize?: Omit<GroupType, 'icon' | 'id'>) => {
  if (row.group == null) {
    return null;
  }

  const group = GROUPS[row.group as SignatureGroup];
  if (!group) {
    return null;
  }

  return (
    <div className="flex justify-center items-center">
      <img src={group.icon} style={{ width: customSize?.w ?? group.w, height: customSize?.h ?? group.h }} />
    </div>
  );
};
