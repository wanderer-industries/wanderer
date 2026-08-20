import { SIGNATURES_GLOWINGROWS_TIMING } from '@/hooks/Mapper/constants/signatures.ts';

export const to_5: MigrationStructure = {
  to: 5,
  up: (prev: any) => {
 const signatureSettings = prev?.signatures || {};

    return {
      ...prev,
      signatures: {
        ...signatureSettings,
        glowingrows_timing: signatureSettings.glowingrows_timing ?? SIGNATURES_GLOWINGROWS_TIMING.GLOWDEFAULT,
      },
    };
  },
};
