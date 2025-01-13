import { PrettySwitchbox } from '@/hooks/Mapper/components/mapRootContent/components/MapSettings/components';
import { WIDGETS_CHECKBOXES_PROPS, WidgetsIds } from '@/hooks/Mapper/components/mapInterface/constants.tsx';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback } from 'react';

export interface WidgetsSettingsProps {}

// eslint-disable-next-line no-empty-pattern
export const WidgetsSettings = ({}: WidgetsSettingsProps) => {
  const { windowsVisible, setWindowsVisible } = useMapRootState();

  const handleWidgetSettingsChange = useCallback(
    (widget: WidgetsIds, checked: boolean) => {
      setWindowsVisible(prev => {
        if (checked) {
          return [...prev, widget];
        }

        return prev.filter(x => x !== widget);
      });
    },
    [setWindowsVisible],
  );

  return (
    <div className="">
      {WIDGETS_CHECKBOXES_PROPS.map(widget => (
        <PrettySwitchbox
          key={widget.id}
          label={widget.label}
          checked={windowsVisible.some(x => x === widget.id)}
          setChecked={checked => handleWidgetSettingsChange(widget.id, checked)}
        />
      ))}
    </div>
  );
};
