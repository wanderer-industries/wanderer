import useLocalStorageState from 'use-local-storage-state';
import { InterfaceStoredSettings, RoutesType } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { DEFAULT_ROUTES_SETTINGS, STORED_INTERFACE_DEFAULT_VALUES } from '@/hooks/Mapper/mapRootProvider/constants.ts';
import { useActualizeSettings } from '@/hooks/Mapper/hooks';
import { useEffect } from 'react';
import { SESSION_KEY } from '@/hooks/Mapper/constants.ts';

export const useMigrationRoutesSettingsV1 = (update: (upd: RoutesType) => void) => {
  //TODO if current Date is more than 01.01.2026 - remove this hook.

  useEffect(() => {
    const items = localStorage.getItem(SESSION_KEY.routes);
    if (items) {
      update(JSON.parse(items));
      localStorage.removeItem(SESSION_KEY.routes);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
};

export const useMapUserSettings = () => {
  const [interfaceSettings, setInterfaceSettings] = useLocalStorageState<InterfaceStoredSettings>(
    'window:interface:settings',
    {
      defaultValue: STORED_INTERFACE_DEFAULT_VALUES,
    },
  );

  const [settingsRoutes, settingsRoutesUpdate] = useLocalStorageState<RoutesType>('window:interface:routes', {
    defaultValue: DEFAULT_ROUTES_SETTINGS,
  });

  useActualizeSettings(STORED_INTERFACE_DEFAULT_VALUES, interfaceSettings, setInterfaceSettings);
  useActualizeSettings(DEFAULT_ROUTES_SETTINGS, settingsRoutes, settingsRoutesUpdate);

  useMigrationRoutesSettingsV1(settingsRoutesUpdate);

  return { interfaceSettings, setInterfaceSettings, settingsRoutes, settingsRoutesUpdate };
};
