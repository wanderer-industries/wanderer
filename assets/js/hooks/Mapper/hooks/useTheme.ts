import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { AvailableThemes } from '@/hooks/Mapper/mapRootProvider/types.ts';

export const useTheme = (): AvailableThemes => {
  const { storedSettings } = useMapRootState();

  return storedSettings.interfaceSettings.theme;
};
