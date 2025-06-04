import { Menu } from 'primereact/menu';
import { useCallback, useMemo, useRef } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { TooltipPosition } from '@/hooks/Mapper/components/ui-kit';
import { OutCommand } from '@/hooks/Mapper/types';
import { MenuItem } from 'primereact/menuitem';
import { useMapCheckPermissions } from '@/hooks/Mapper/mapRootProvider/hooks/api';
import { UserPermission } from '@/hooks/Mapper/types/permissions.ts';

export interface MapContextMenuProps {
  onShowOnTheMap?: () => void;
  onShowMapSettings?: () => void;
  onShowTrackingDialog?: () => void;
}

export const MapContextMenu = ({ onShowOnTheMap, onShowMapSettings, onShowTrackingDialog }: MapContextMenuProps) => {
  const {
    outCommand,
    storedSettings: { setInterfaceSettings },
  } = useMapRootState();

  const canTrackCharacters = useMapCheckPermissions([UserPermission.TRACK_CHARACTER]);

  const menuRight = useRef<Menu>(null);

  const handleShowActivity = useCallback(() => {
    outCommand({
      type: OutCommand.showActivity,
      data: {},
    });
  }, [outCommand]);

  const items = useMemo(() => {
    return (
      [
        {
          label: 'Tracking',
          icon: 'pi pi-user-plus',
          command: onShowTrackingDialog,
          visible: canTrackCharacters,
        },
        {
          label: 'Character Activity',
          icon: 'pi pi-chart-bar',
          command: handleShowActivity,
          visible: canTrackCharacters,
        },
        {
          label: 'On the map',
          icon: 'pi pi-hashtag',
          command: onShowOnTheMap,
          visible: canTrackCharacters,
        },
        { separator: true, visible: true },
        {
          label: 'Settings',
          icon: `pi pi-cog`,
          command: onShowMapSettings,
          visible: true,
        },
        {
          label: 'Dock menu',
          icon: 'pi pi-window-maximize',
          command: () =>
            setInterfaceSettings(x => ({
              ...x,
              isShowMenu: !x.isShowMenu,
            })),
          visible: true,
        },
      ] as MenuItem[]
    ).filter(item => item.visible);
  }, [
    canTrackCharacters,
    onShowTrackingDialog,
    handleShowActivity,
    onShowMapSettings,
    onShowOnTheMap,
    setInterfaceSettings,
  ]);

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
