import { MigrationStructure, MigrationTypes } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { omit } from '@/hooks/Mapper/utils/omit.ts';

export const to_3: MigrationStructure = {
  to: 3,
  type: MigrationTypes.interface,
  run: (prev: any) => {
    return {
      ...omit(prev, ['test2', 'kek2']),
      test3: 'lol ke1333',
      kek3: 'kek1333',
    };
  },
};
