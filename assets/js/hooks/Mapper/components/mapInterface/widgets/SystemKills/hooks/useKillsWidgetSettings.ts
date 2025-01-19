import useLocalStorageState from 'use-local-storage-state';

interface KillsWidgetSettings {
  showAllVisible: boolean;
  compact: boolean;
}

export function useKillsWidgetSettings() {
  return useLocalStorageState<KillsWidgetSettings>('kills:widget:settings', {
    defaultValue: {
      showAllVisible: false,
      compact: false,
    },
  });
}
