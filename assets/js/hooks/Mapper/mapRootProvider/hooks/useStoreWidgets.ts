import { DEFAULT_WIDGETS, WidgetsIds } from '@/hooks/Mapper/components/mapInterface/constants.tsx';
import { WindowProps } from '@/hooks/Mapper/components/ui-kit/WindowManager/types.ts';
import { Dispatch, SetStateAction, useCallback, useRef } from 'react';
import { WindowsManagerOnChange } from '@/hooks/Mapper/components/ui-kit/WindowManager';
import { getDefaultWidgetProps } from '@/hooks/Mapper/mapRootProvider/constants.ts';

export type StoredWindowProps = Omit<WindowProps, 'content'>;
export type WindowStoreInfo = {
  windows: StoredWindowProps[];
  visible: WidgetsIds[];
  viewPort?: { w: number; h: number } | undefined;
};
// export type UpdateWidgetSettingsFunc = (widgets: WindowProps[]) => void;
export type ToggleWidgetVisibility = (widgetId: WidgetsIds) => void;

interface UseStoreWidgetsProps {
  windowsSettings: WindowStoreInfo;
  windowsSettingsUpdate: Dispatch<SetStateAction<WindowStoreInfo>>;
}

export const useStoreWidgets = ({ windowsSettings, windowsSettingsUpdate }: UseStoreWidgetsProps) => {
  const ref = useRef({ windowsSettings, windowsSettingsUpdate });
  ref.current = { windowsSettings, windowsSettingsUpdate };

  const updateWidgetSettings: WindowsManagerOnChange = useCallback(({ windows, viewPort }) => {
    const { windowsSettingsUpdate } = ref.current;

    windowsSettingsUpdate(({ visible /*, windows*/ }: WindowStoreInfo) => {
      return {
        // eslint-disable-next-line @typescript-eslint/no-unused-vars
        windows: DEFAULT_WIDGETS.map(({ content, ...x }) => {
          const windowProp = windows.find(j => j.id === x.id);
          if (windowProp) {
            return windowProp;
          }

          return x;
        }),
        viewPort,
        visible,
      };
    });
  }, []);

  const toggleWidgetVisibility: ToggleWidgetVisibility = useCallback(widgetId => {
    const { windowsSettingsUpdate } = ref.current;

    windowsSettingsUpdate(({ visible, windows, ...x }) => {
      const isCheckedPrev = visible.includes(widgetId);
      if (!isCheckedPrev) {
        const maxZIndex = Math.max(...windows.map(w => w.zIndex));
        return {
          ...x,
          windows: windows.map(wnd => {
            if (wnd.id === widgetId) {
              return { ...wnd, /*position: { x: SNAP_GAP, y: SNAP_GAP },*/ zIndex: maxZIndex + 1 };
            }

            return wnd;
          }),
          visible: [...visible, widgetId],
        };
      }

      return {
        ...x,
        windows,
        visible: visible.filter(x => x !== widgetId),
      };
    });
  }, []);

  const resetWidgets = useCallback(() => ref.current.windowsSettingsUpdate(getDefaultWidgetProps()), []);

  return {
    windowsSettings,
    updateWidgetSettings,
    toggleWidgetVisibility,
    resetWidgets,
  };
};
