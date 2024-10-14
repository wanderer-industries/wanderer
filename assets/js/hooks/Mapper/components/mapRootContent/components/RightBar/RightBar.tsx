import classes from './RightBar.module.scss';
import clsx from 'clsx';
import { useCallback } from 'react';
import { OutCommand } from '@/hooks/Mapper/types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { TooltipPosition } from '@/hooks/Mapper/components/ui-kit';

interface RightBarProps {
  onShowOnTheMap?: () => void;
}

export const RightBar = ({ onShowOnTheMap }: RightBarProps) => {
  const { outCommand, interfaceSettings, setInterfaceSettings } = useMapRootState();

  const isShowMinimap = interfaceSettings.isShowMinimap === undefined ? true : interfaceSettings.isShowMinimap;

  const handleAddCharacter = useCallback(() => {
    outCommand({
      type: OutCommand.addCharacter,
      data: null,
    });
  }, [outCommand]);

  const handleOpenUserSettings = useCallback(() => {
    outCommand({
      type: OutCommand.openUserSettings,
      data: null,
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
            onClick={handleAddCharacter}
          >
            <i className="pi pi-user-plus"></i>
          </button>
        </WdTooltipWrapper>

        <WdTooltipWrapper content="User settings" position={TooltipPosition.left}>
          <button
            className="btn bg-transparent text-gray-400 hover:text-white border-transparent hover:bg-transparent py-2 h-auto min-h-auto"
            type="button"
            onClick={handleOpenUserSettings}
          >
            <i className="pi pi-cog"></i>
          </button>
        </WdTooltipWrapper>

        <WdTooltipWrapper content="Show on the map" position={TooltipPosition.left}>
          <button
            className="btn bg-transparent text-gray-400 hover:text-white border-transparent hover:bg-transparent py-2 h-auto min-h-auto"
            type="button"
            onClick={onShowOnTheMap}
          >
            <i className="pi pi-hashtag"></i>
          </button>
        </WdTooltipWrapper>
      </div>

      <div className="flex flex-col items-center mb-2 gap-1">
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
