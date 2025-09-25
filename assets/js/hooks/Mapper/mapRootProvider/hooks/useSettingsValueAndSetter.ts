import { Dispatch, SetStateAction, useCallback, useMemo, useRef } from 'react';
import { MapUserSettings, MapUserSettingsStructure, SettingsWrapper } from '@/hooks/Mapper/mapRootProvider/types.ts';

type ExtractSettings<S extends keyof MapUserSettings> = MapUserSettings[S] extends SettingsWrapper<infer U> ? U : never;

type Setter<S extends keyof MapUserSettings> = (
  value: Partial<ExtractSettings<S>> | ((prev: ExtractSettings<S>) => Partial<ExtractSettings<S>>),
  version?: number,
) => void;

type GenerateSettingsReturn<S extends keyof MapUserSettings> = [ExtractSettings<S>, Setter<S>];

export const useSettingsValueAndSetter = <S extends keyof MapUserSettings>(
  settings: MapUserSettingsStructure,
  setSettings: Dispatch<SetStateAction<MapUserSettingsStructure>>,
  mapId: string | null,
  setting: S,
): GenerateSettingsReturn<S> => {
  const data = useMemo<ExtractSettings<S>>(() => {
    if (!mapId) return {} as ExtractSettings<S>;

    const mapSettings = settings[mapId];
    return (mapSettings?.[setting] ?? ({} as ExtractSettings<S>)) as ExtractSettings<S>;
  }, [mapId, setting, settings]);

  const refData = useRef({ mapId, setting, setSettings });
  refData.current = { mapId, setting, setSettings };

  const setter = useCallback<Setter<S>>(value => {
    const { mapId, setting, setSettings } = refData.current;

    if (!mapId) return;

    setSettings(all => {
      const currentMap = all[mapId];
      const prev = currentMap[setting] as ExtractSettings<S>;

      const patch =
        typeof value === 'function' ? (value as (p: ExtractSettings<S>) => Partial<ExtractSettings<S>>)(prev) : value;

      return {
        ...all,
        [mapId]: {
          ...currentMap,
          [setting]: { ...(prev as any), ...patch } as ExtractSettings<S>,
        },
      };
    });
  }, []);

  return [data, setter];
};
