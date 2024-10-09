import { SystemSignature } from '@/hooks/Mapper/types';
import { GROUPS_LIST } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/constants.ts';
import { getState } from './getState.ts';

export const getActualSigs = (
  oldSignatures: SystemSignature[],
  newSignatures: SystemSignature[],
  updateOnly: boolean,
): { added: SystemSignature[]; updated: SystemSignature[]; removed: SystemSignature[] } => {
  const updated: SystemSignature[] = [];
  const removed: SystemSignature[] = [];

  oldSignatures.forEach(oldSig => {
    // if old sigs is not contains in newSigs we need mark it as removed
    // otherwise we check
    const newSig = newSignatures.find(s => s.eve_id === oldSig.eve_id);
    if (newSig) {
      // we take new sig and now we need check that sig has been updated
      const isNeedUpgrade = getState(GROUPS_LIST, newSig) > getState(GROUPS_LIST, oldSig);
      if (isNeedUpgrade) {
        updated.push({ ...oldSig, group: newSig.group, name: newSig.name });
      }
    } else {
      if (!updateOnly) {
        removed.push(oldSig);
      }
    }
  });

  const oldSignaturesIds = oldSignatures.map(x => x.eve_id);
  const added = newSignatures.filter(s => !oldSignaturesIds.includes(s.eve_id));

  return { added, updated, removed };
};
