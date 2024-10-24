import { COSMIC_SIGNATURE } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/SystemSignatureSettingsDialog';
import { SystemSignature } from '@/hooks/Mapper/types';

export const parseSignatures = (value: string, availableKeys: string[]): SystemSignature[] => {
  const outArr: SystemSignature[] = [];
  const rows = value.split('\n');

  for (let a = 0; a < rows.length; a++) {
    const row = rows[a];

    const sigArrInfo = row.split('	');

    if (sigArrInfo.length !== 6) {
      continue;
    }

    outArr.push({
      eve_id: sigArrInfo[0],
      kind: availableKeys.includes(sigArrInfo[1]) ? sigArrInfo[1] : COSMIC_SIGNATURE,
      group: sigArrInfo[2],
      name: sigArrInfo[3],
      type: '',
    });
  }

  return outArr;
};
