import { MigrationStructure } from '@/hooks/Mapper/mapRootProvider/types.ts';

export const to_1: MigrationStructure = {
  to: 1,
  up: (prev: any) => {
    return Object.keys(prev).reduce((acc, k) => {
      return { ...acc, [k]: prev[k].settings };
    }, Object.create(null));
  },
  down: (prev: any) => {
    return Object.keys(prev).reduce((acc, k) => {
      return { ...acc, [k]: { version: 0, settings: prev[k] } };
    }, Object.create(null));
  },
};
