import { DotlanBehavior } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { to_6 } from './to_6.ts';

describe('to_6', () => {
  it('adds the default Dotlan behavior to existing interface settings', () => {
    const previousSettings = {
      interface: {
        isShowMenu: true,
      },
    };

    expect(to_6.up(previousSettings).interface).toMatchObject({
      dotlanBehavior: DotlanBehavior.system,
      isShowMenu: true,
    });
  });

  it('preserves an existing Dotlan behavior', () => {
    const previousSettings = {
      interface: {
        dotlanBehavior: DotlanBehavior.kills,
      },
    };

    expect(to_6.up(previousSettings).interface.dotlanBehavior).toBe(DotlanBehavior.kills);
  });
});
