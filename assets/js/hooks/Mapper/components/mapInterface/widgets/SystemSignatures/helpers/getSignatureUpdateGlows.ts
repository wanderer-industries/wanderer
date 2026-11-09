import type { ExtendedSystemSignature } from '@/hooks/Mapper/types';
import type { GlowingRowInfo } from '../hooks/types';

export const getSignatureUpdateGlows = (
  previousSignatures: ExtendedSystemSignature[],
  nextSignatures: ExtendedSystemSignature[],
  systemId: string,
): Map<string, GlowingRowInfo> => {
  const previousById = new Map(previousSignatures.map(signature => [signature.eve_id, signature]));
  const glowingRows = new Map<string, GlowingRowInfo>();

  nextSignatures.forEach(signature => {
    if (signature.deleted) {
      return;
    }

    const previousSignature = previousById.get(signature.eve_id);
    if (!previousSignature) {
      glowingRows.set(signature.eve_id, { isNew: true, systemId });
      return;
    }

    if (previousSignature.updated_at !== signature.updated_at) {
      glowingRows.set(signature.eve_id, { isNew: false, systemId });
    }
  });

  return glowingRows;
};
