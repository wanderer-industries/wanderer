import useLocalStorageState from 'use-local-storage-state';

export interface LocalCharacterWidgetSettings {
  compact: boolean;
  showOffline: boolean;
  version: number;
  showShipName: boolean;
}

export const LOCAL_CHARACTER_WIDGET_DEFAULT: LocalCharacterWidgetSettings = {
  compact: true,
  showOffline: false,
  version: 0,
  showShipName: false,
};

export function useLocalCharacterWidgetSettings() {
  return useLocalStorageState<LocalCharacterWidgetSettings>('kills:widget:settings', {
    defaultValue: LOCAL_CHARACTER_WIDGET_DEFAULT,
  });
}
