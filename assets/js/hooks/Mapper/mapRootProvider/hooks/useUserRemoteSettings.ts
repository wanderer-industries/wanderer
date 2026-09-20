import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { OutCommandHandler } from '@/hooks/Mapper/types';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers.ts';
import { DEFAULT_REMOTE_SETTINGS } from '@/hooks/Mapper/constants/userSettings.ts';
import { UserSettingsRemote } from '@/hooks/Mapper/components/mapRootContent/components/MapSettings/types.ts';
import { parseSystemLabels, SystemLabelDefinition } from '@/hooks/Mapper/constants/labels.ts';

export type UseUserRemoteSettingsData = {
  userRemoteSettings: UserSettingsRemote;
  setUserRemoteSettings: (settings: UserSettingsRemote) => void;
  systemLabels: SystemLabelDefinition[];
  refreshUserRemoteSettings: () => Promise<void>;
};

const RETRY_TIMEOUTS = [300, 700, 1500, 3000, 5000, 10000];

/**
 * Remote user settings are needed outside of the settings dialog as well - system labels
 * are rendered on every node - so they are loaded once here and shared through map root state.
 */
export const useUserRemoteSettings = (outCommand: OutCommandHandler): UseUserRemoteSettingsData => {
  const [userRemoteSettings, setUserRemoteSettings] = useState<UserSettingsRemote>({ ...DEFAULT_REMOTE_SETTINGS });

  const ref = useRef({ outCommand });
  ref.current = { outCommand };

  const refreshUserRemoteSettings = useCallback(async () => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const res: any = await ref.current.outCommand({ type: OutCommand.getUserSettings, data: null });

    if (!res?.user_settings) {
      throw new Error('no user settings in response');
    }

    setUserRemoteSettings(prev => ({ ...prev, ...res.user_settings }));
  }, []);

  useEffect(() => {
    let retryTimer: ReturnType<typeof setTimeout> | undefined;
    let cancelled = false;

    // the map channel is not joined yet on first render, so keep trying - until it
    // succeeds every label on the map would render with default names
    const load = (attempt: number) => {
      refreshUserRemoteSettings().catch(() => {
        const timeout = RETRY_TIMEOUTS[attempt];

        if (cancelled || timeout === undefined) {
          return;
        }

        retryTimer = setTimeout(() => load(attempt + 1), timeout);
      });
    };

    load(0);

    return () => {
      cancelled = true;
      clearTimeout(retryTimer);
    };
  }, [refreshUserRemoteSettings]);

  const systemLabels = useMemo(
    () => parseSystemLabels(userRemoteSettings.system_labels),
    [userRemoteSettings.system_labels],
  );

  // settings stored before a new key existed come back without it - keep defaults for those
  const handleSetUserRemoteSettings = useCallback(
    (settings: UserSettingsRemote) => setUserRemoteSettings({ ...DEFAULT_REMOTE_SETTINGS, ...settings }),
    [],
  );

  return {
    userRemoteSettings,
    setUserRemoteSettings: handleSetUserRemoteSettings,
    systemLabels,
    refreshUserRemoteSettings,
  };
};
