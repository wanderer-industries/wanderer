import { SignatureGroup, SignatureKind, SystemSignature } from '@/hooks/Mapper/types';
import { MAPPING_TYPE_TO_ENG } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/constants.ts';

export const parseSignatures = (value: string, availableKeys: string[]): SystemSignature[] => {
  const outArr: SystemSignature[] = [];
  const rows = value.split('\n');

  for (let a = 0; a < rows.length; a++) {
    const row = rows[a];

    const sigArrInfo = row.split('	');

    if (sigArrInfo.length !== 6) {
      continue;
    }

    const kind = MAPPING_TYPE_TO_ENG[sigArrInfo[1] as SignatureKind];

    outArr.push({
      eve_id: sigArrInfo[0],
      kind: availableKeys.includes(kind) ? kind : SignatureKind.CosmicSignature,
      group: sigArrInfo[2] as SignatureGroup,
      name: sigArrInfo[3],
      type: '',
    });
  }

  return outArr;
};
