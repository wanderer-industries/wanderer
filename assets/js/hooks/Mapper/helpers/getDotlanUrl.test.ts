import { DotlanBehavior } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { getDotlanUrl } from './getDotlanUrl.ts';

const BASE_PARAMS = {
  isWormhole: false,
  regionName: 'The Forge',
  systemName: 'Jita',
};

describe('getDotlanUrl', () => {
  it('opens system information when that behavior is selected', () => {
    expect(getDotlanUrl({ ...BASE_PARAMS, behavior: DotlanBehavior.system })).toBe(
      'https://evemaps.dotlan.net/system/Jita',
    );
  });

  it('opens the selected regional map layer', () => {
    expect(getDotlanUrl({ ...BASE_PARAMS, behavior: DotlanBehavior.security })).toBe(
      'https://evemaps.dotlan.net/map/The_Forge/Jita#sec',
    );
  });

  it('always opens system information for wormhole systems', () => {
    expect(
      getDotlanUrl({
        ...BASE_PARAMS,
        behavior: DotlanBehavior.jumps,
        isWormhole: true,
        systemName: 'J123456',
      }),
    ).toBe('https://evemaps.dotlan.net/system/J123456');
  });
});
