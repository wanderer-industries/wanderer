import { useMemo, useCallback } from 'react';
import useLocalStorageState from 'use-local-storage-state';

export interface KillsWidgetSettings {
  compact: boolean;
  showAll: boolean;
  whOnly: boolean;
  excludedSystems: number[];
  version: number;
  timeRange: number;
}

export const DEFAULT_KILLS_WIDGET_SETTINGS: KillsWidgetSettings = {
  compact: true,
  showAll: false,
  whOnly: true,
  excludedSystems: [],
  version: 1,
  timeRange: 1,
};

function mergeWithDefaults(settings?: Partial<KillsWidgetSettings>): KillsWidgetSettings {
  if (!settings) {
    return DEFAULT_KILLS_WIDGET_SETTINGS;
  }

  return {
    ...DEFAULT_KILLS_WIDGET_SETTINGS,
    ...settings,
    excludedSystems: Array.isArray(settings.excludedSystems) ? settings.excludedSystems : [],
  };
}

export function useKillsWidgetSettings() {
  const [rawValue, setRawValue] = useLocalStorageState<KillsWidgetSettings | undefined>('kills:widget:settings');

  const value = useMemo<KillsWidgetSettings>(() => {
    return mergeWithDefaults(rawValue);
  }, [rawValue]);

  const setValue = useCallback(
    (newVal: KillsWidgetSettings | ((prev: KillsWidgetSettings) => KillsWidgetSettings)) => {
      setRawValue(prev => {
        const mergedPrev = mergeWithDefaults(prev);

        const nextUnmerged = typeof newVal === 'function' ? newVal(mergedPrev) : newVal;

        return mergeWithDefaults(nextUnmerged);
      });
    },
    [setRawValue],
  );

  return [value, setValue] as const;
}
