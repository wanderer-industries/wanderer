import { PrettySwitchbox } from '@/hooks/Mapper/components/mapRootContent/components/MapSettings/components/index.ts';
import { WIDGETS_CHECKBOXES_PROPS, WidgetsIds } from '@/hooks/Mapper/components/mapInterface/constants.tsx';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback } from 'react';
import { WdButton } from '@/hooks/Mapper/components/ui-kit';

export interface WidgetsSettingsProps {}

// eslint-disable-next-line no-empty-pattern
export const WidgetsSettings = ({}: WidgetsSettingsProps) => {
  const { windowsSettings, toggleWidgetVisibility, resetWidgets } = useMapRootState();

  const handleWidgetSettingsChange = useCallback(
    (widget: WidgetsIds) => toggleWidgetVisibility(widget),
    [toggleWidgetVisibility],
  );

  return (
    <div className="flex flex-col h-full gap-2">
      <div>
        {WIDGETS_CHECKBOXES_PROPS.map(widget => (
          <PrettySwitchbox
            key={widget.id}
            label={widget.label}
            checked={windowsSettings.visible.some(x => x === widget.id)}
            setChecked={() => handleWidgetSettingsChange(widget.id)}
          />
        ))}
      </div>

      <div className="border-b-2 border-dotted border-stone-700/50 h-px my-3" />

      <div className="grid grid-cols-[1fr_auto]">
        <div />
        <WdButton className="py-[4px]" onClick={resetWidgets} outlined size="small" label="Reset Widgets" />
      </div>
    </div>
  );
};
