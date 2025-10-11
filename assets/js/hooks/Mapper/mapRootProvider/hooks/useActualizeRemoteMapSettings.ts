import { OutCommand, OutCommandHandler } from '@/hooks/Mapper/types';
import { Dispatch, SetStateAction, useCallback, useEffect, useRef } from 'react';
import {
  MapUserSettings,
  MapUserSettingsStructure,
  RemoteAdminSettingsResponse,
} from '@/hooks/Mapper/mapRootProvider/types.ts';
import { createDefaultStoredSettings } from '@/hooks/Mapper/mapRootProvider/helpers/createDefaultStoredSettings.ts';
import { applyMigrations } from '@/hooks/Mapper/mapRootProvider/migrations';

interface UseActualizeRemoteMapSettingsProps {
  outCommand: OutCommandHandler;
  mapUserSettings: MapUserSettingsStructure;
  applySettings: (val: MapUserSettings) => void;
  setMapUserSettings: Dispatch<SetStateAction<MapUserSettingsStructure>>;
  map_slug: string | null;
}

export const useActualizeRemoteMapSettings = ({
  outCommand,
  mapUserSettings,
  setMapUserSettings,
  applySettings,
  map_slug,
}: UseActualizeRemoteMapSettingsProps) => {
  const refVars = useRef({ applySettings, mapUserSettings, setMapUserSettings, map_slug });
  refVars.current = { applySettings, mapUserSettings, setMapUserSettings, map_slug };

  const actualizeRemoteMapSettings = useCallback(async () => {
    const { applySettings } = refVars.current;

    let res: RemoteAdminSettingsResponse | undefined;
    try {
      res = await outCommand({ type: OutCommand.getDefaultSettings, data: null });
    } catch (error) {
      // do nothing
    }

    if (res?.default_settings == null) {
      applySettings(createDefaultStoredSettings());
      return;
    }

    try {
      applySettings(applyMigrations(JSON.parse(res.default_settings) || createDefaultStoredSettings()));
    } catch (error) {
      applySettings(createDefaultStoredSettings());
    }
  }, [outCommand]);

  useEffect(() => {
    const { mapUserSettings } = refVars.current;

    // INFO: Do nothing if slug is not set
    if (map_slug == null) {
      return;
    }

    // INFO: Do nothing if user have already data
    if (map_slug in mapUserSettings) {
      return;
    }

    actualizeRemoteMapSettings();
  }, [actualizeRemoteMapSettings, map_slug]);
};
