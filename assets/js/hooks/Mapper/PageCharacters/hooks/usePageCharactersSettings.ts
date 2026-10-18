import { useCallback, useEffect, useMemo } from 'react';
import fastDeepEqual from 'fast-deep-equal';
import useLocalStorageState from 'use-local-storage-state';
import { createDefaultPageCharactersSettings, normalizePageCharactersSettings } from '../settings/defaults';
import { applyPageCharactersSettingsMigrations } from '../settings/migrations';
import type { PageCharactersSettingsPatch } from '../settings/types';
import { PAGE_CHARACTERS_SETTINGS_KEY } from '../settings/version';

type PageCharactersSettingsUpdater =
  | PageCharactersSettingsPatch
  | ((current: ReturnType<typeof createDefaultPageCharactersSettings>) => PageCharactersSettingsPatch);

export const usePageCharactersSettings = () => {
  const [storedSettings, setStoredSettings] = useLocalStorageState<unknown>(PAGE_CHARACTERS_SETTINGS_KEY, {
    defaultValue: createDefaultPageCharactersSettings(),
  });

  const settings = useMemo(() => applyPageCharactersSettingsMigrations(storedSettings), [storedSettings]);

  useEffect(() => {
    if (!fastDeepEqual(storedSettings, settings)) {
      setStoredSettings(settings);
    }
  }, [setStoredSettings, settings, storedSettings]);

  const updateSettings = useCallback(
    (updater: PageCharactersSettingsUpdater) => {
      setStoredSettings((currentValue: unknown) => {
        const currentSettings = applyPageCharactersSettingsMigrations(currentValue);
        const patch = typeof updater === 'function' ? updater(currentSettings) : updater;
        return normalizePageCharactersSettings({ ...currentSettings, ...patch });
      });
    },
    [setStoredSettings],
  );

  const resetSettings = useCallback(() => {
    setStoredSettings(createDefaultPageCharactersSettings());
  }, [setStoredSettings]);

  return { settings, updateSettings, resetSettings };
};
