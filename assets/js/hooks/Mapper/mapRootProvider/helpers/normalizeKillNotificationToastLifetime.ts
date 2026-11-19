import { DEFAULT_KILL_NOTIFICATION_TOAST_LIFETIME_SECONDS } from '@/hooks/Mapper/mapRootProvider/constants.ts';

export const normalizeKillNotificationToastLifetime = (value: unknown) => {
  if (typeof value === 'number') {
    return value;
  }

  if (value && typeof value === 'object' && 'value' in value && typeof value.value === 'number') {
    return value.value;
  }

  return DEFAULT_KILL_NOTIFICATION_TOAST_LIFETIME_SECONDS;
};
