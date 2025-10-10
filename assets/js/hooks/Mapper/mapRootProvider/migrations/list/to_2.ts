import { MigrationStructure } from '@/hooks/Mapper/mapRootProvider/types.ts';

const IN_V1_STORE_KEY = 'viewPort';
const IN_V1_DEFAULT_VIEWPORT = { zoom: 1, x: 0, y: 0 };

export const to_2: MigrationStructure = {
  to: 2,
  up: (prev: any) => {
    const restored = localStorage.getItem(IN_V1_STORE_KEY);
    let current = IN_V1_DEFAULT_VIEWPORT;
    if (restored != null) {
      try {
        current = JSON.parse(restored);
      } catch (err) {
        // do nothing
      }

      localStorage.removeItem(IN_V1_STORE_KEY);
    }

    return {
      ...prev,
      map: {
        viewport: current,
      },
    };
  },
};
