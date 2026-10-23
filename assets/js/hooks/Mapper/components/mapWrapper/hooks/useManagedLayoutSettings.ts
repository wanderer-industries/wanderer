import { ManagedLayoutDirection } from '@/hooks/Mapper/components/map/map.types.ts';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers.ts';
import { useEffect, useState } from 'react';

const LAYOUT_SETTINGS_RETRY_DELAY_MS = 500;
const LAYOUT_SETTINGS_MAX_ATTEMPTS = 5;

interface LayoutSettingsStatus {
  available: boolean;
  enabled: boolean;
  direction: ManagedLayoutDirection;
}

export interface ManagedLayoutSettings {
  enabled: boolean;
  direction: ManagedLayoutDirection;
}

const INITIAL_SETTINGS: ManagedLayoutSettings = {
  enabled: false,
  direction: ManagedLayoutDirection.LeftRight,
};

export const useManagedLayoutSettings = (): ManagedLayoutSettings => {
  const {
    outCommand,
    data: { systems },
  } = useMapRootState();
  const [settings, setSettings] = useState<ManagedLayoutSettings>(INITIAL_SETTINGS);
  const systemsPositionKey = systems.map(system => `${system.id}:${system.position.x}:${system.position.y}`).join('|');

  useEffect(() => {
    let active = true;
    let retryTimer: ReturnType<typeof setTimeout> | undefined;

    const loadLayoutSettings = (attempt: number) => {
      void outCommand<LayoutSettingsStatus>({ type: OutCommand.getLayoutSettings, data: null })
        .then(status => {
          if (!active) return;
          setSettings({ enabled: status.enabled, direction: status.direction });
        })
        .catch(() => {
          if (!active) return;

          if (attempt < LAYOUT_SETTINGS_MAX_ATTEMPTS) {
            retryTimer = setTimeout(() => loadLayoutSettings(attempt + 1), LAYOUT_SETTINGS_RETRY_DELAY_MS);
            return;
          }

          setSettings(current => ({ ...current, enabled: false }));
        });
    };

    loadLayoutSettings(1);

    return () => {
      active = false;
      if (retryTimer) clearTimeout(retryTimer);
    };
  }, [outCommand, systemsPositionKey]);

  return settings;
};
