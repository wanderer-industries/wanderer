import useLocalStorageState from 'use-local-storage-state';
import { MapUserSettings, MapUserSettingsStructure } from '@/hooks/Mapper/mapRootProvider/types.ts';
import {
  DEFAULT_KILLS_WIDGET_SETTINGS,
  DEFAULT_ON_THE_MAP_SETTINGS,
  DEFAULT_ROUTES_SETTINGS,
  DEFAULT_WIDGET_LOCAL_SETTINGS,
  getDefaultWidgetProps,
  STORED_INTERFACE_DEFAULT_VALUES,
} from '@/hooks/Mapper/mapRootProvider/constants.ts';
import { useCallback, useEffect, useRef, useState } from 'react';
import { DEFAULT_SIGNATURE_SETTINGS } from '@/hooks/Mapper/constants/signatures';
import { MapRootData } from '@/hooks/Mapper/mapRootProvider';
import { useSettingsValueAndSetter } from '@/hooks/Mapper/mapRootProvider/hooks/useSettingsValueAndSetter.ts';
import fastDeepEqual from 'fast-deep-equal';

// import { actualizeSettings } from '@/hooks/Mapper/mapRootProvider/helpers';

// TODO - we need provide and compare version
const createWidgetSettingsWithVersion = <T>(settings: T) => {
  return {
    version: 0,
    settings,
  };
};

const createDefaultWidgetSettings = (): MapUserSettings => {
  return {
    killsWidget: createWidgetSettingsWithVersion(DEFAULT_KILLS_WIDGET_SETTINGS),
    localWidget: createWidgetSettingsWithVersion(DEFAULT_WIDGET_LOCAL_SETTINGS),
    widgets: createWidgetSettingsWithVersion(getDefaultWidgetProps()),
    routes: createWidgetSettingsWithVersion(DEFAULT_ROUTES_SETTINGS),
    onTheMap: createWidgetSettingsWithVersion(DEFAULT_ON_THE_MAP_SETTINGS),
    signaturesWidget: createWidgetSettingsWithVersion(DEFAULT_SIGNATURE_SETTINGS),
    interface: createWidgetSettingsWithVersion(STORED_INTERFACE_DEFAULT_VALUES),
  };
};

const EMPTY_OBJ = {};

export const useMapUserSettings = ({ map_slug }: MapRootData) => {
  const [isReady, setIsReady] = useState(false);
  const [hasOldSettings, setHasOldSettings] = useState(false);

  const [mapUserSettings, setMapUserSettings] = useLocalStorageState<MapUserSettingsStructure>('map-user-settings', {
    defaultValue: EMPTY_OBJ,
  });

  const ref = useRef({ mapUserSettings, setMapUserSettings, map_slug });
  ref.current = { mapUserSettings, setMapUserSettings, map_slug };

  useEffect(() => {
    const { mapUserSettings, setMapUserSettings } = ref.current;
    if (map_slug === null) {
      return;
    }

    if (!(map_slug in mapUserSettings)) {
      setMapUserSettings({
        ...mapUserSettings,
        [map_slug]: createDefaultWidgetSettings(),
      });
    }
  }, [map_slug]);

  const [interfaceSettings, setInterfaceSettings] = useSettingsValueAndSetter(
    mapUserSettings,
    setMapUserSettings,
    map_slug,
    'interface',
  );

  const [settingsRoutes, settingsRoutesUpdate] = useSettingsValueAndSetter(
    mapUserSettings,
    setMapUserSettings,
    map_slug,
    'routes',
  );

  const [settingsLocal, settingsLocalUpdate] = useSettingsValueAndSetter(
    mapUserSettings,
    setMapUserSettings,
    map_slug,
    'localWidget',
  );

  const [settingsSignatures, settingsSignaturesUpdate] = useSettingsValueAndSetter(
    mapUserSettings,
    setMapUserSettings,
    map_slug,
    'signaturesWidget',
  );

  const [settingsOnTheMap, settingsOnTheMapUpdate] = useSettingsValueAndSetter(
    mapUserSettings,
    setMapUserSettings,
    map_slug,
    'onTheMap',
  );

  const [settingsKills, settingsKillsUpdate] = useSettingsValueAndSetter(
    mapUserSettings,
    setMapUserSettings,
    map_slug,
    'killsWidget',
  );

  const [windowsSettings, setWindowsSettings] = useSettingsValueAndSetter(
    mapUserSettings,
    setMapUserSettings,
    map_slug,
    'widgets',
  );

  // HERE we MUST work with migrations
  useEffect(() => {
    if (isReady) {
      return;
    }

    if (map_slug === null) {
      return;
    }

    if (mapUserSettings[map_slug] == null) {
      return;
    }

    // TODO !!!! FROM this date 06.07.2025 - we must work only with migrations
    // actualizeSettings(STORED_INTERFACE_DEFAULT_VALUES, interfaceSettings, setInterfaceSettings);
    // actualizeSettings(DEFAULT_ROUTES_SETTINGS, settingsRoutes, settingsRoutesUpdate);
    // actualizeSettings(DEFAULT_WIDGET_LOCAL_SETTINGS, settingsLocal, settingsLocalUpdate);
    // actualizeSettings(DEFAULT_SIGNATURE_SETTINGS, settingsSignatures, settingsSignaturesUpdate);
    // actualizeSettings(DEFAULT_ON_THE_MAP_SETTINGS, settingsOnTheMap, settingsOnTheMapUpdate);
    // actualizeSettings(DEFAULT_KILLS_WIDGET_SETTINGS, settingsKills, settingsKillsUpdate);

    setIsReady(true);
  }, [
    map_slug,
    mapUserSettings,
    interfaceSettings,
    setInterfaceSettings,
    settingsRoutes,
    settingsRoutesUpdate,
    settingsLocal,
    settingsLocalUpdate,
    settingsSignatures,
    settingsSignaturesUpdate,
    settingsOnTheMap,
    settingsOnTheMapUpdate,
    settingsKills,
    settingsKillsUpdate,
    isReady,
  ]);

  const checkOldSettings = useCallback(() => {
    const interfaceSettings = localStorage.getItem('window:interface:settings');
    const widgetRoutes = localStorage.getItem('window:interface:routes');
    const widgetLocal = localStorage.getItem('window:interface:local');
    const widgetKills = localStorage.getItem('kills:widget:settings');
    const onTheMapOld = localStorage.getItem('window:onTheMap:settings');
    const widgetsOld = localStorage.getItem('windows:settings:v2');

    setHasOldSettings(!!(widgetsOld || interfaceSettings || widgetRoutes || widgetLocal || widgetKills || onTheMapOld));
  }, []);

  useEffect(() => {
    checkOldSettings();
  }, [checkOldSettings]);

  const getSettingsForExport = useCallback(() => {
    const { map_slug } = ref.current;

    if (map_slug == null) {
      return;
    }

    return JSON.stringify(ref.current.mapUserSettings[map_slug]);
  }, []);

  const applySettings = useCallback((settings: MapUserSettings) => {
    const { map_slug, mapUserSettings, setMapUserSettings } = ref.current;

    if (map_slug == null) {
      return false;
    }

    if (fastDeepEqual(settings, mapUserSettings[map_slug])) {
      return false;
    }

    setMapUserSettings(old => ({
      ...old,
      [map_slug]: settings,
    }));
    return true;
  }, []);

  return {
    isReady,
    hasOldSettings,

    interfaceSettings,
    setInterfaceSettings,
    settingsRoutes,
    settingsRoutesUpdate,
    settingsLocal,
    settingsLocalUpdate,
    settingsSignatures,
    settingsSignaturesUpdate,
    settingsOnTheMap,
    settingsOnTheMapUpdate,
    settingsKills,
    settingsKillsUpdate,
    windowsSettings,
    setWindowsSettings,

    getSettingsForExport,
    applySettings,
    checkOldSettings,
  };
};
