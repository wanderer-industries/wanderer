import { SIGNATURES_GLOWINGROWS_TIMING } from '@/hooks/Mapper/components/mapInterface/components/signatures/signatures.ts';
import { DEFAULT_JUMP_PLANNER_SETTINGS } from '@/hooks/Mapper/mapRootProvider/constants.ts';
import { MigrationStructure } from '@/hooks/Mapper/mapRootProvider/types.ts';

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
      jumpPlanner: {
        ...DEFAULT_JUMP_PLANNER_SETTINGS,
        ...prev?.jumpPlanner,
      },
    };
  },
};
