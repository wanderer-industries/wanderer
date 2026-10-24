import { SIGNATURES_GLOWINGROWS_TIMING } from '@/hooks/Mapper/constants/signatures.ts';
import { MigrationStructure } from '@/hooks/Mapper/mapRootProvider/types.ts';

export const to_7: MigrationStructure = {
  to: 7,
  up: prev => {
    const signatureSettings = prev?.signaturesWidget || {};

    return {
      ...prev,
      signaturesWidget: {
        ...signatureSettings,
        glowingrows_timing: signatureSettings.glowingrows_timing ?? SIGNATURES_GLOWINGROWS_TIMING.GLOWDEFAULT,
      },
    };
  },
};
