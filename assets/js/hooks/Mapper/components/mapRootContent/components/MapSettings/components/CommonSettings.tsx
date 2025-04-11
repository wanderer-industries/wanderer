import { COMMON_CHECKBOXES_PROPS } from '@/hooks/Mapper/components/mapRootContent/components/MapSettings/constants.ts';
import { useMapSettings } from '@/hooks/Mapper/components/mapRootContent/components/MapSettings/MapSettingsProvider.tsx';
import { SettingsListItem } from '@/hooks/Mapper/components/mapRootContent/components/MapSettings/types.ts';

export const CommonSettings = () => {
  const { renderSettingItem } = useMapSettings();

  const renderSettingsList = (list: SettingsListItem[]) => {
    return list.map(renderSettingItem);
  };

  return <div className="w-full h-full flex flex-col gap-1">{renderSettingsList(COMMON_CHECKBOXES_PROPS)}</div>;
};
