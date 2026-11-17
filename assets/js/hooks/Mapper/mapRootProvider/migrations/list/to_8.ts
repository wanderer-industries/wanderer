import { MigrationStructure } from '@/hooks/Mapper/mapRootProvider/types.ts';

const DEFAULT_KILL_NOTIFICATION_SCOPES = ['wormhole', 'highSec', 'lowSec', 'nullSec', 'pochven', 'other'];
const DEFAULT_KILL_NOTIFICATION_TOAST_LIFETIME_SECONDS = 0;

export const to_8: MigrationStructure = {
  to: 8,
  up: prev => ({
    ...prev,
    interface: {
      ...prev?.interface,
      killActivityNotifications: prev?.interface?.killActivityNotifications ?? false,
      killActivitySounds: prev?.interface?.killActivitySounds ?? false,
      killActivityExcludedSystems: prev?.interface?.killActivityExcludedSystems ?? [],
      killActivityScopes: prev?.interface?.killActivityScopes ?? DEFAULT_KILL_NOTIFICATION_SCOPES,
      killActivityToastLifetimeSeconds:
        prev?.interface?.killActivityToastLifetimeSeconds ?? DEFAULT_KILL_NOTIFICATION_TOAST_LIFETIME_SECONDS,
    },
  }),
};
