import { useMemo } from 'react';
import { SolarSystemStaticInfoRaw } from '@/hooks/Mapper/types';
import {
  SOLAR_SYSTEM_CLASS_GROUPS,
  SOLAR_SYSTEM_CLASSES_TO_CLASS_GROUPS,
  WORMHOLES_ADDITIONAL_INFO_BY_CLASS_ID,
} from '@/hooks/Mapper/components/map/constants.ts';

interface UseSystemNameParams {
  isTempSystemNameEnabled: boolean;
  temporary_name?: string | null;
  isShowLinkedSigIdTempName: boolean;
  linkedSigPrefix: string | null;
  name?: string | null;
  systemStaticInfo: SolarSystemStaticInfoRaw;
}

export const useSystemName = ({
  isTempSystemNameEnabled,
  temporary_name,
  isShowLinkedSigIdTempName,
  linkedSigPrefix,
  name,
  systemStaticInfo,
}: UseSystemNameParams) => {
  const { solar_system_name = '', system_class } = systemStaticInfo;

  const systemPreparedName = useMemo(() => {
    const { id: whType, shortTitle } = WORMHOLES_ADDITIONAL_INFO_BY_CLASS_ID[system_class];

    // @ts-ignore
    const spawnClassGroup = SOLAR_SYSTEM_CLASSES_TO_CLASS_GROUPS[whType];
    if (spawnClassGroup === SOLAR_SYSTEM_CLASS_GROUPS.drifter) {
      return shortTitle;
    }

    return solar_system_name;
  }, [system_class, solar_system_name]);

  const computedTemporaryName = useMemo(() => {
    if (!isTempSystemNameEnabled) {
      return '';
    }

    if (isShowLinkedSigIdTempName && linkedSigPrefix) {
      return temporary_name ? `${linkedSigPrefix}・${temporary_name}` : `${linkedSigPrefix}・${systemPreparedName}`;
    }

    return temporary_name ?? '';
  }, [isTempSystemNameEnabled, temporary_name, systemPreparedName, isShowLinkedSigIdTempName, linkedSigPrefix]);

  const systemName = useMemo(() => {
    if (isTempSystemNameEnabled && computedTemporaryName) {
      return computedTemporaryName;
    }

    return systemPreparedName;
  }, [isTempSystemNameEnabled, computedTemporaryName, systemPreparedName]);

  const customName = useMemo(() => {
    if (isTempSystemNameEnabled && computedTemporaryName && name) {
      return name;
    }

    if (solar_system_name !== name && name) {
      return name;
    }

    return null;
  }, [isTempSystemNameEnabled, computedTemporaryName, name, solar_system_name]);

  return { systemName, computedTemporaryName, customName };
};
