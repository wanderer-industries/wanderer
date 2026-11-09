import { DEFAULT_JUMP_PLANNER_SETTINGS } from '@/hooks/Mapper/mapRootProvider/constants.ts';
import { MigrationStructure } from '@/hooks/Mapper/mapRootProvider/types.ts';

export const to_5: MigrationStructure = {
  to: 5,
  up: prev => {
    return {
      ...prev,
      jumpPlanner: {
        ...DEFAULT_JUMP_PLANNER_SETTINGS,
        ...prev?.jumpPlanner,
      },
    };
  },
};
