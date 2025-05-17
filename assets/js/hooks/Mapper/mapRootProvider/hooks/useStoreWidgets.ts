import useLocalStorageState from 'use-local-storage-state';
import {
  CURRENT_WINDOWS_VERSION,
  DEFAULT_WIDGETS,
  STORED_VISIBLE_WIDGETS_DEFAULT,
  WidgetsIds,
  WINDOWS_LOCAL_STORE_KEY,
} from '@/hooks/Mapper/components/mapInterface/constants.tsx';
import { WindowProps } from '@/hooks/Mapper/components/ui-kit/WindowManager/types.ts';
import { useCallback, useEffect, useRef } from 'react';
import { SNAP_GAP, WindowsManagerOnChange } from '@/hooks/Mapper/components/ui-kit/WindowManager';

export type StoredWindowProps = Omit<WindowProps, 'content'>;
export type WindowStoreInfo = {
  version: number;
  windows: StoredWindowProps[];
  visible: WidgetsIds[];
  viewPort?: { w: number; h: number } | undefined;
};
export type UpdateWidgetSettingsFunc = (widgets: WindowProps[]) => void;
export type ToggleWidgetVisibility = (widgetId: WidgetsIds) => void;

export const getDefaultWidgetProps = () => ({
  version: CURRENT_WINDOWS_VERSION,
  visible: STORED_VISIBLE_WIDGETS_DEFAULT,
  windows: DEFAULT_WIDGETS,
});

export const useStoreWidgets = () => {
  const [windowsSettings, setWindowsSettings] = useLocalStorageState<WindowStoreInfo>(WINDOWS_LOCAL_STORE_KEY, {
    defaultValue: getDefaultWidgetProps(),
  });

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

  // eslint-disable-next-line no-console
  console.log('JOipP', `windowsSettings`, windowsSettings);

  return {
    windowsSettings,
    updateWidgetSettings,
    toggleWidgetVisibility,
    resetWidgets,
  };
};
