import { to_8 } from './to_8.ts';

const DEFAULT_KILL_NOTIFICATION_SCOPES = ['wormhole', 'highSec', 'lowSec', 'nullSec', 'pochven', 'other'];

describe('to_8', () => {
  it('adds default kill activity notification settings', () => {
    const migrated = to_8.up({ interface: { isShowMenu: true } });

    expect(migrated.interface).toEqual({
      isShowMenu: true,
      killActivityNotifications: false,
      killActivitySounds: false,
      killActivityExcludedSystems: [],
      killActivityScopes: DEFAULT_KILL_NOTIFICATION_SCOPES,
      killActivityToastLifetimeSeconds: 0,
    });
  });

  it('preserves existing kill activity notification settings', () => {
    const migrated = to_8.up({
      interface: {
        killActivityNotifications: true,
        killActivitySounds: true,
        killActivityExcludedSystems: [30_000_142],
        killActivityScopes: ['wormhole'],
        killActivityToastLifetimeSeconds: 30,
      },
    });

    expect(migrated.interface.killActivityNotifications).toBe(true);
    expect(migrated.interface.killActivitySounds).toBe(true);
    expect(migrated.interface.killActivityExcludedSystems).toEqual([30_000_142]);
    expect(migrated.interface.killActivityScopes).toEqual(['wormhole']);
    expect(migrated.interface.killActivityToastLifetimeSeconds).toBe(30);
  });
});
