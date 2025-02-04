import { useMemo } from 'react';
import { WindowManager } from '@/hooks/Mapper/components/ui-kit/WindowManager';
import { DEFAULT_WIDGETS } from '@/hooks/Mapper/components/mapInterface/constants.tsx';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

export const MapInterface = () => {
  // const [items, setItems] = useState<WindowProps[]>(restoreWindowsFromLS);
  const { windowsSettings, updateWidgetSettings } = useMapRootState();

  const items = useMemo(() => {
    return windowsSettings.windows
      .map(x => {
        const content = DEFAULT_WIDGETS.find(y => y.id === x.id)?.content;
        return {
          ...x,
          content: content!,
        };
      })
      .filter(x => windowsSettings.visible.some(j => x.id === j));
  }, [windowsSettings]);

  return (
    <WindowManager
      windows={items}
      viewPort={windowsSettings.viewPort}
      dragSelector=".react-grid-dragHandleExample"
      onChange={updateWidgetSettings}
    />
  );
};
