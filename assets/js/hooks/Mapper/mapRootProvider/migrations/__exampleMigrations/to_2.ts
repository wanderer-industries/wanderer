import { MigrationStructure, MigrationTypes } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { omit } from '@/hooks/Mapper/utils/omit.ts';

export const to_2: MigrationStructure = {
  to: 2,
  type: MigrationTypes.interface,
  run: (prev: any) => {
    return {
      ...omit(prev, ['test1', 'kek1']),
      test2: 'lol ke1',
      kek2: 'kek1',
    };
  },
};
