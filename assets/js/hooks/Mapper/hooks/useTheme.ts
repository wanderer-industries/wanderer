import { AvailableThemes, useMapRootState } from '@/hooks/Mapper/mapRootProvider';

export const useTheme = (): AvailableThemes => {
  const { interfaceSettings } = useMapRootState();

  return interfaceSettings.theme;
};
