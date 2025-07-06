import {
  CURRENT_WINDOWS_VERSION,
  DEFAULT_WIDGETS,
  WidgetsIds,
  WINDOWS_LOCAL_STORE_KEY,
} from '@/hooks/Mapper/components/mapInterface/constants.tsx';
import { WindowProps } from '@/hooks/Mapper/components/ui-kit/WindowManager/types.ts';
import { Dispatch, SetStateAction, useCallback, useEffect, useRef } from 'react';
import { WindowsManagerOnChange } from '@/hooks/Mapper/components/ui-kit/WindowManager';
import { getDefaultWidgetProps } from '@/hooks/Mapper/mapRootProvider/constants.ts';

export type StoredWindowProps = Omit<WindowProps, 'content'>;
export type WindowStoreInfo = {
  version: number;
  windows: StoredWindowProps[];
  visible: WidgetsIds[];
  viewPort?: { w: number; h: number } | undefined;
};
// export type UpdateWidgetSettingsFunc = (widgets: WindowProps[]) => void;
export type ToggleWidgetVisibility = (widgetId: WidgetsIds) => void;

interface UseStoreWidgetsProps {
  windowsSettings: WindowStoreInfo;
  setWindowsSettings: Dispatch<SetStateAction<WindowStoreInfo>>;
}

export const useStoreWidgets = ({ windowsSettings, setWindowsSettings }: UseStoreWidgetsProps) => {
  const ref = useRef({ windowsSettings, setWindowsSettings });
  ref.current = { windowsSettings, setWindowsSettings };

  const updateWidgetSettings: WindowsManagerOnChange = useCallback(({ windows, viewPort }) => {
    const { setWindowsSettings } = ref.current;

    setWindowsSettings(({ version, visible /*, windows*/ }: WindowStoreInfo) => {
      return {
        version,
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
    const { setWindowsSettings } = ref.current;

    setWindowsSettings(({ visible, windows, ...x }) => {
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

  useEffect(() => {
    const { setWindowsSettings } = ref.current;

    const raw = localStorage.getItem(WINDOWS_LOCAL_STORE_KEY);
    if (!raw) {
      console.warn('No windows found in local storage!!');

      setWindowsSettings(getDefaultWidgetProps());
      return;
    }

    const { version, windows, visible, viewPort } = JSON.parse(raw) as WindowStoreInfo;
    if (!version || CURRENT_WINDOWS_VERSION > version) {
      setWindowsSettings(getDefaultWidgetProps());
    }

    // eslint-disable-next-line no-debugger
    const out = windows.filter(x => DEFAULT_WIDGETS.find(def => def.id === x.id));

    setWindowsSettings({
      version: CURRENT_WINDOWS_VERSION,
      windows: out as WindowProps[],
      visible,
      viewPort,
    });
  }, []);

  const resetWidgets = useCallback(() => ref.current.setWindowsSettings(getDefaultWidgetProps()), []);

  return {
    windowsSettings,
    updateWidgetSettings,
    toggleWidgetVisibility,
    resetWidgets,
  };
};
