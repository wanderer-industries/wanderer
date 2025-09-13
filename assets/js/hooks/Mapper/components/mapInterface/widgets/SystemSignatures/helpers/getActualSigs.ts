import { GROUPS_LIST } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/constants';
import { SystemSignature } from '@/hooks/Mapper/types';
import { getState } from './getState';

/**
 * Compare two lists of signatures and return which are added, updated, or removed.
 *
 * @param oldSignatures existing signatures (in memory or from server)
 * @param newSignatures newly parsed or incoming signatures from user input
 * @param updateOnly    if true, do NOT remove old signatures not found in newSignatures
 * @param skipUpdateUntouched if true, do NOT push unmodified signatures into the `updated` array
 */
export const getActualSigs = (
  oldSignatures: SystemSignature[],
  newSignatures: SystemSignature[],
  updateOnly?: boolean,
  skipUpdateUntouched?: boolean,
): { added: SystemSignature[]; updated: SystemSignature[]; removed: SystemSignature[] } => {
  const updated: SystemSignature[] = [];
  const removed: SystemSignature[] = [];
  const added: SystemSignature[] = [];

  oldSignatures.forEach(oldSig => {
    const newSig = newSignatures.find(s => s.eve_id === oldSig.eve_id);

    if (newSig) {
      const needUpgrade = getState(GROUPS_LIST, newSig) > getState(GROUPS_LIST, oldSig);
      const mergedSig = { ...oldSig };
      let changed = false;

      if (needUpgrade) {
        mergedSig.group = newSig.group;
        mergedSig.name = newSig.name;
        changed = true;
      }
      if (newSig.description && newSig.description !== oldSig.description) {
        mergedSig.description = newSig.description;
        changed = true;
      }

      try {
        const oldInfo = JSON.parse(oldSig.custom_info || '{}');
        const newInfo = JSON.parse(newSig.custom_info || '{}');
        let infoChanged = false;
        for (const key in newInfo) {
          if (oldInfo[key] !== newInfo[key]) {
            oldInfo[key] = newInfo[key];
            infoChanged = true;
          }
        }
        if (infoChanged) {
          mergedSig.custom_info = JSON.stringify(oldInfo);
          changed = true;
        }
      } catch (e) {
        console.error(`getActualSigs: Error merging custom_info for ${oldSig.eve_id}`, e);
      }

      if (newSig.updated_at !== oldSig.updated_at) {
        mergedSig.updated_at = newSig.updated_at;
        changed = true;
      }

      if (changed) {
        updated.push(mergedSig);
      } else if (!skipUpdateUntouched) {
        updated.push({ ...oldSig });
      }
    } else {
      if (!updateOnly) {
        removed.push(oldSig);
      }
    }
  });

  const oldIds = new Set(oldSignatures.map(x => x.eve_id));
  newSignatures.forEach(s => {
    if (!oldIds.has(s.eve_id)) {
      added.push(s);
    }
  });

  return { added, updated, removed };
};
