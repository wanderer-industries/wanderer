import classes from './RightBar.module.scss';
import clsx from 'clsx';
import { useCallback } from 'react';
import { OutCommand } from '@/hooks/Mapper/types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { TooltipPosition } from '@/hooks/Mapper/components/ui-kit';

import { useMapCheckPermissions } from '@/hooks/Mapper/mapRootProvider/hooks/api';
import { UserPermission } from '@/hooks/Mapper/types/permissions.ts';

interface RightBarProps {
  onShowOnTheMap?: () => void;
  onShowMapSettings?: () => void;
}

export const RightBar = ({ onShowOnTheMap, onShowMapSettings }: RightBarProps) => {
  const { outCommand, interfaceSettings, setInterfaceSettings } = useMapRootState();

  const canTrackCharacters = useMapCheckPermissions([UserPermission.TRACK_CHARACTER]);

  const isShowMinimap = interfaceSettings.isShowMinimap === undefined ? true : interfaceSettings.isShowMinimap;

  const handleShowTracking = useCallback(() => {
    // Use the OutCommand pattern for showing the tracking dialog
    outCommand({
      type: OutCommand.showTracking,
      data: {},
    });
  }, [outCommand]);

  const toggleMinimap = useCallback(() => {
    setInterfaceSettings(x => ({
      ...x,
      isShowMinimap: !x.isShowMinimap,
    }));
  }, [setInterfaceSettings]);

  const toggleKSpace = useCallback(() => {
    setInterfaceSettings(x => ({
      ...x,
      isShowKSpace: !x.isShowKSpace,
    }));
  }, [setInterfaceSettings]);

  const toggleMenu = useCallback(() => {
    setInterfaceSettings(x => ({
      ...x,
      isShowMenu: !x.isShowMenu,
    }));
  }, [setInterfaceSettings]);

  return (
    <div
      className={clsx(
        classes.RightBarRoot,
        'w-full h-full',
        'text-gray-200 shadow-lg border-l border-zinc-800 border-opacity-70 bg-opacity-70 bg-neutral-900',
        'flex flex-col items-center justify-between',
      )}
    >
      <div className="flex flex-col gap-2 items-center mt-1">
        <WdTooltipWrapper content="Tracking status" position={TooltipPosition.left}>
          <button
            className="btn bg-transparent text-gray-400 hover:text-white border-transparent hover:bg-transparent py-2 h-auto min-h-auto"
            type="button"
            onClick={handleShowTracking}
            id="show-tracking-button"
          >
            <i className="pi pi-user-plus"></i>
          </button>
        </WdTooltipWrapper>

        {canTrackCharacters && (
          <>
            <WdTooltipWrapper content="Show on the map" position={TooltipPosition.left}>
              <button
                className="btn bg-transparent text-gray-400 hover:text-white border-transparent hover:bg-transparent py-2 h-auto min-h-auto"
                type="button"
                onClick={onShowOnTheMap}
              >
                <i className="pi pi-hashtag"></i>
              </button>
            </WdTooltipWrapper>
          </>
        )}
      </div>

      <div className="flex flex-col items-center mb-2 gap-1">
        <WdTooltipWrapper content="Map user settings" position={TooltipPosition.left}>
          <button
            className="btn bg-transparent text-gray-400 hover:text-white border-transparent hover:bg-transparent py-2 h-auto min-h-auto"
            type="button"
            onClick={onShowMapSettings}
          >
            <i className="pi pi-cog"></i>
          </button>
        </WdTooltipWrapper>

        <WdTooltipWrapper
          content={
            interfaceSettings.isShowKSpace ? 'Hide highlighting Imperial Space' : 'Show highlighting Imperial Space'
          }
          position={TooltipPosition.left}
        >
          <button
            className="btn bg-transparent text-gray-400 hover:text-white border-transparent hover:bg-transparent py-2 h-auto min-h-auto"
            type="button"
            onClick={toggleKSpace}
          >
            <i className={interfaceSettings.isShowKSpace ? 'hero-cloud-solid' : 'hero-cloud'}></i>
          </button>
        </WdTooltipWrapper>

        <WdTooltipWrapper content={isShowMinimap ? 'Hide minimap' : 'Show minimap'} position={TooltipPosition.left}>
          <button
            className="btn bg-transparent text-gray-400 hover:text-white border-transparent hover:bg-transparent py-2 h-auto min-h-auto"
            type="button"
            onClick={toggleMinimap}
          >
            <i className={isShowMinimap ? 'pi pi-eye' : 'pi pi-eye-slash'}></i>
          </button>
        </WdTooltipWrapper>

        <WdTooltipWrapper content="Switch to menu" position={TooltipPosition.left}>
          <button
            className="btn bg-transparent text-gray-400 hover:text-white border-transparent hover:bg-transparent py-2 h-auto min-h-auto"
            type="button"
            onClick={toggleMenu}
          >
            <i className="pi pi-window-minimize"></i>
          </button>
        </WdTooltipWrapper>
      </div>
    </div>
  );
};
