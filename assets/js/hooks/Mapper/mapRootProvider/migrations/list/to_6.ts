import { DotlanBehavior, MigrationStructure } from '@/hooks/Mapper/mapRootProvider/types.ts';

export const to_6: MigrationStructure = {
  to: 6,
  up: prev => ({
    ...prev,
    interface: {
      ...prev?.interface,
      dotlanBehavior: prev?.interface?.dotlanBehavior ?? DotlanBehavior.system,
    },
  }),
};
