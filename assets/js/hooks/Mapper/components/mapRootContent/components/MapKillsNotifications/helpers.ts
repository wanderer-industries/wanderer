import { SOLAR_SYSTEM_CLASS_IDS } from '@/hooks/Mapper/components/map/constants.ts';
import { isWormholeSpace } from '@/hooks/Mapper/components/map/helpers/isWormholeSpace.ts';
import { DEFAULT_KILL_NOTIFICATION_SCOPES } from '@/hooks/Mapper/mapRootProvider/constants.ts';
import { getSystemStaticInfo } from '@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic.ts';
import { InterfaceStoredSettings, KillNotificationScope } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { DetailedKill } from '@/hooks/Mapper/types/kills.ts';
import { SolarSystemRawType } from '@/hooks/Mapper/types/system.ts';

const MINUTE_MS = 60 * 1_000;
const RECENT_KILL_WINDOW_MS = 15 * MINUTE_MS;

export interface PendingKillNotification {
  kill: DetailedKill;
  system: SolarSystemRawType;
  timestamp: number;
}

export const getKillTimestamp = (kill: DetailedKill) => {
  if (!kill.kill_time) {
    return null;
  }

  const timestamp = Date.parse(kill.kill_time);
  return Number.isNaN(timestamp) ? null : timestamp;
};

export const isRecentKill = (timestamp: number) => {
  const age = Date.now() - timestamp;
  return age >= 0 && age <= RECENT_KILL_WINDOW_MS;
};

export const findKillSystem = (systems: SolarSystemRawType[], systemId: string) => {
  return systems.find(system => {
    return system.id === systemId || system.system_static_info?.solar_system_id.toString() === systemId;
  });
};

const getKillNotificationScope = (systemClass: number) => {
  if (isWormholeSpace(systemClass)) {
    return KillNotificationScope.wormhole;
  }

  switch (systemClass) {
    case SOLAR_SYSTEM_CLASS_IDS.hs:
      return KillNotificationScope.highSec;
    case SOLAR_SYSTEM_CLASS_IDS.ls:
      return KillNotificationScope.lowSec;
    case SOLAR_SYSTEM_CLASS_IDS.ns:
      return KillNotificationScope.nullSec;
    case SOLAR_SYSTEM_CLASS_IDS.pochven:
      return KillNotificationScope.pochven;
    default:
      return KillNotificationScope.other;
  }
};

export const isSystemIncluded = (
  system: SolarSystemRawType,
  solarSystemId: number,
  settings: InterfaceStoredSettings,
) => {
  const systemInfo = system.system_static_info ?? getSystemStaticInfo(solarSystemId);
  if (!systemInfo) {
    return false;
  }

  const excludedSystems = settings.killActivityExcludedSystems ?? [];
  if (excludedSystems.includes(systemInfo.solar_system_id)) {
    return false;
  }

  const selectedScopes = settings.killActivityScopes ?? DEFAULT_KILL_NOTIFICATION_SCOPES;
  const scope = getKillNotificationScope(Number(systemInfo.system_class));
  return selectedScopes.includes(scope);
};
