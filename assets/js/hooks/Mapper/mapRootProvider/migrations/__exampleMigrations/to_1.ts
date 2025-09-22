import { MigrationStructure, MigrationTypes } from '@/hooks/Mapper/mapRootProvider/types.ts';

export const to_1: MigrationStructure = {
  to: 1,
  type: MigrationTypes.interface,
  run: (prev: any) => {
    return {
      ...prev,
      test1: 'lol ke',
      kek1: 'kek',
    };
  },
};
