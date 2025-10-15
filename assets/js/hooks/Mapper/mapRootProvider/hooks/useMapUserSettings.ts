import useLocalStorageState from 'use-local-storage-state';
import { MapUserSettings, MapUserSettingsStructure } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { useCallback, useEffect, useRef, useState } from 'react';
import { MapRootData } from '@/hooks/Mapper/mapRootProvider';
import { useSettingsValueAndSetter } from '@/hooks/Mapper/mapRootProvider/hooks/useSettingsValueAndSetter.ts';
import fastDeepEqual from 'fast-deep-equal';
import { OutCommandHandler } from '@/hooks/Mapper/types';
import { useActualizeRemoteMapSettings } from '@/hooks/Mapper/mapRootProvider/hooks/useActualizeRemoteMapSettings.ts';
import { createDefaultStoredSettings } from '@/hooks/Mapper/mapRootProvider/helpers/createDefaultStoredSettings.ts';
import { applyMigrations, extractData } from '@/hooks/Mapper/mapRootProvider/migrations';
import { LS_KEY, LS_KEY_LEGASY } from '@/hooks/Mapper/mapRootProvider/version.ts';

const EMPTY_OBJ = {};

export const useMapUserSettings = ({ map_slug }: MapRootData, outCommand: OutCommandHandler) => {
  const [isReady, setIsReady] = useState(false);
  const [hasOldSettings, setHasOldSettings] = useState(false);

  const [mapUserSettings, setMapUserSettings] = useLocalStorageState<MapUserSettingsStructure>(LS_KEY, {
    defaultValue: EMPTY_OBJ,
  });

  const ref = useRef({ mapUserSettings, setMapUserSettings, map_slug });
  ref.current = { mapUserSettings, setMapUserSettings, map_slug };

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

  useActualizeRemoteMapSettings({ outCommand, applySettings, mapUserSettings, setMapUserSettings, map_slug });

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

  const [windowsSettings, windowsSettingsUpdate] = useSettingsValueAndSetter(
    mapUserSettings,
    setMapUserSettings,
    map_slug,
    'widgets',
  );

  const [mapSettings, mapSettingsUpdate] = useSettingsValueAndSetter(
    mapUserSettings,
    setMapUserSettings,
    map_slug,
    'map',
  );

  // HERE we MUST work with migrations
  useEffect(() => {
    if (isReady) {
      return;
    }

    if (map_slug === null) {
      return;
    }

    const currentMapUserSettings = mapUserSettings[map_slug];
    if (currentMapUserSettings == null) {
      return;
    }

    try {
      // here we try to restore settings
      let oldMapData;
      if (!currentMapUserSettings.migratedFromOld) {
        const allData = extractData(LS_KEY_LEGASY);
        oldMapData = allData?.[map_slug];
      }

      // INFO: after migrations migratedFromOld always will be true
      const migratedResult = applyMigrations(oldMapData ? oldMapData : currentMapUserSettings);

      if (!migratedResult) {
        setIsReady(true);
        return;
      }

      setMapUserSettings({ ...mapUserSettings, [map_slug]: migratedResult });
      setIsReady(true);
    } catch (error) {
      setIsReady(true);
    }
  }, [isReady, mapUserSettings, map_slug, setMapUserSettings]);

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

  const resetSettings = useCallback(() => {
    applySettings(createDefaultStoredSettings());
  }, [applySettings]);

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
    windowsSettingsUpdate,
    mapSettings,
    mapSettingsUpdate,

    getSettingsForExport,
    applySettings,
    resetSettings,
    checkOldSettings,
  };
};
