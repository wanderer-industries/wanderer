import { Menu } from 'primereact/menu';
import { useCallback, useMemo, useRef } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { TooltipPosition } from '@/hooks/Mapper/components/ui-kit';
import { OutCommand } from '@/hooks/Mapper/types';
import { MenuItem } from 'primereact/menuitem';

export interface MapContextMenuProps {
  onShowOnTheMap?: () => void;
}

export const MapContextMenu = ({ onShowOnTheMap }: MapContextMenuProps) => {
  const { outCommand, interfaceSettings, setInterfaceSettings } = useMapRootState();

  const menuRight = useRef<Menu>(null);

  const handleAddCharacter = useCallback(() => {
    outCommand({
      type: OutCommand.addCharacter,
      data: null,
    });
  }, [outCommand]);

  const toggleMinimap = useCallback(() => {
    setInterfaceSettings(x => ({
      ...x,
      isShowMinimap: !x.isShowMinimap,
    }));
  }, [setInterfaceSettings]);

  const items = useMemo(() => {
    return [
      {
        label: 'Tracking',
        icon: 'pi pi-user-plus',
        command: handleAddCharacter,
      },
      {
        label: 'On the map',
        icon: 'pi pi-hashtag',
        command: onShowOnTheMap,
      },
      { separator: true },
      {
        label: interfaceSettings.isShowMinimap ? 'Hide minimap' : 'Show minimap',
        icon: `pi ${interfaceSettings.isShowMinimap ? 'pi-eye-slash' : 'pi-eye'}`,
        command: toggleMinimap,
      },
      {
        label: 'Dock menu',
        icon: 'pi pi-window-maximize',
        command: () =>
          setInterfaceSettings(x => ({
            ...x,
            isShowMenu: !x.isShowMenu,
          })),
      },
    ] as MenuItem[];
  }, [handleAddCharacter, interfaceSettings.isShowMinimap, onShowOnTheMap, setInterfaceSettings, toggleMinimap]);

  return (
    <div className="ml-1">
      <WdTooltipWrapper content="Map Menu" position={TooltipPosition.left}>
        <button
          className="btn bg-transparent text-gray-400 hover:text-white border-transparent hover:bg-transparent px-2"
          type="button"
          onClick={event => menuRight.current?.toggle(event)}
        >
          <i className="pi pi-sliders-h text-lg"></i>
        </button>
      </WdTooltipWrapper>
      <Menu model={items} popup ref={menuRight} id="popup_menu_right" popupAlignment="right" />
    </div>
  );
};
