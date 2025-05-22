import {
  MAPPING_GROUP_TO_ENG,
  MAPPING_TYPE_TO_ENG,
} from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/constants.ts';
import { SignatureGroup, SignatureKind, SystemSignature } from '@/hooks/Mapper/types';

export const UNKNOWN_SIGNATURE_NAME = 'Unknown';

export const parseSignatures = (value: string, availableKeys: string[]): SystemSignature[] => {
  const outArr: SystemSignature[] = [];
  const rows = value.split('\n');

  for (let a = 0; a < rows.length; a++) {
    const row = rows[a];

    const sigArrInfo = row.split('	');

    if (sigArrInfo.length !== 6) {
      continue;
    }

    // Extract the signature ID and check if it's valid (XXX-XXX format)
    const sigId = sigArrInfo[0];

    if (!sigId || !sigId.match(/^[A-Z]{3}-\d{3}$/)) {
      continue;
    }

    // Try to map the kind, or fall back to CosmicSignature if unknown
    const typeString = sigArrInfo[1];
    let kind = SignatureKind.CosmicSignature;

    // Try to map the kind using the flattened mapping
    const mappedKind = MAPPING_TYPE_TO_ENG[typeString];

    if (mappedKind && availableKeys.includes(mappedKind)) {
      kind = mappedKind;
    }

    // Try to map the group, or fall back to CosmicSignature if unknown
    const rawGroup = sigArrInfo[2];
    let group = SignatureGroup.CosmicSignature;

    // Try to map the group using the flattened mapping
    const mappedGroup = MAPPING_GROUP_TO_ENG[rawGroup];
    if (mappedGroup) {
      group = mappedGroup;
    }

    const signature: SystemSignature = {
      eve_id: sigId,
      kind,
      group,
      name: sigArrInfo[3] || UNKNOWN_SIGNATURE_NAME,
      type: '',
    };

    outArr.push(signature);
  }

  return outArr;
};
