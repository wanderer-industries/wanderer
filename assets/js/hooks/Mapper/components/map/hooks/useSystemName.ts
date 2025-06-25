import { SolarSystemStaticInfoRaw } from '@/hooks/Mapper/types';
import { useMemo } from 'react';

interface UseSystemNameParams {
  isTempSystemNameEnabled: boolean;
  temporary_name?: string | null;
  name?: string | null;
  systemStaticInfo: SolarSystemStaticInfoRaw;
}

export const useSystemName = ({
  isTempSystemNameEnabled,
  temporary_name,
  name,
  systemStaticInfo,
}: UseSystemNameParams) => {
  const { solar_system_name = '' } = systemStaticInfo;

  const computedTemporaryName = useMemo(() => {
    if (!isTempSystemNameEnabled) {
      return '';
    }

    return temporary_name ?? '';
  }, [isTempSystemNameEnabled, temporary_name]);

  const systemName = useMemo(() => {
    if (isTempSystemNameEnabled && computedTemporaryName) {
      return computedTemporaryName;
    }

    return solar_system_name;
  }, [isTempSystemNameEnabled, computedTemporaryName, solar_system_name]);

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
