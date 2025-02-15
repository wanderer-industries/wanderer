// useSystemName.ts
import { useMemo } from 'react';

interface UseSystemNameParams {
  isTempSystemNameEnabled: boolean;
  temporary_name?: string | null;
  solar_system_name: string;
  isShowLinkedSigIdTempName: boolean;
  linkedSigPrefix: string | null;
  name?: string | null;
}

export function useSystemName({
  isTempSystemNameEnabled,
  temporary_name,
  solar_system_name,
  isShowLinkedSigIdTempName,
  linkedSigPrefix,
  name,
}: UseSystemNameParams) {
  const computedTemporaryName = useMemo(() => {
    if (!isTempSystemNameEnabled) {
      return '';
    }
    if (isShowLinkedSigIdTempName && linkedSigPrefix) {
      return temporary_name ? `${linkedSigPrefix}・${temporary_name}` : `${linkedSigPrefix}・${solar_system_name}`;
    }
    return temporary_name ?? '';
  }, [isTempSystemNameEnabled, temporary_name, solar_system_name, isShowLinkedSigIdTempName, linkedSigPrefix]);

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
}
