import {
  MINI_MAP_PLACEMENT,
  PINGS_PLACEMENT,
  THEME_SETTING,
  UI_CHECKBOXES_PROPS,
} from '@/hooks/Mapper/components/mapRootContent/components/MapSettings/constants.ts';
import { useMapSettings } from '@/hooks/Mapper/components/mapRootContent/components/MapSettings/MapSettingsProvider.tsx';
import { SettingsListItem } from '@/hooks/Mapper/components/mapRootContent/components/MapSettings/types.ts';
import { useCallback } from 'react';
import { TooltipPosition, WdButton, WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit';
import { ConfirmPopup } from 'primereact/confirmpopup';
import { useConfirmPopup } from '@/hooks/Mapper/hooks';

export const CommonSettings = () => {
  const { renderSettingItem } = useMapSettings();
  const { cfShow, cfHide, cfVisible, cfRef } = useConfirmPopup();

  const renderSettingsList = useCallback(
    (list: SettingsListItem[]) => {
      return list.map(renderSettingItem);
    },
    [renderSettingItem],
  );

  const handleResetSettings = () => {};

  return (
    <div className="flex flex-col h-full gap-1">
      <div>
        <div className="w-full h-full flex flex-col gap-1">{renderSettingsList(UI_CHECKBOXES_PROPS)}</div>
      </div>

      <div className="border-b-2 border-dotted border-stone-700/50 h-px my-3" />

      <div className="grid grid-cols-[1fr_auto]">{renderSettingItem(MINI_MAP_PLACEMENT)}</div>
      <div className="grid grid-cols-[1fr_auto]">{renderSettingItem(PINGS_PLACEMENT)}</div>
      <div className="grid grid-cols-[1fr_auto]">{renderSettingItem(THEME_SETTING)}</div>

      <div className="border-b-2 border-dotted border-stone-700/50 h-px my-3" />

      <div className="grid grid-cols-[1fr_auto]">
        <div />
        <WdTooltipWrapper content="This dangerous action. And can not be undone" position={TooltipPosition.top}>
          <WdButton
            // @ts-ignore
            ref={cfRef}
            className="py-[4px]"
            onClick={cfShow}
            outlined
            size="small"
            severity="danger"
            label="Reset Settings"
          />
        </WdTooltipWrapper>
      </div>

      <ConfirmPopup
        target={cfRef.current}
        visible={cfVisible}
        onHide={cfHide}
        message="All settings for this map will be reset to default."
        icon="pi pi-exclamation-triangle"
        accept={handleResetSettings}
      />
    </div>
  );
};
