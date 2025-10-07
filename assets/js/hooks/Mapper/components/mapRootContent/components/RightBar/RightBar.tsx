import classes from './RightBar.module.scss';
import clsx from 'clsx';
import { ReactNode, useCallback } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { TooltipPosition } from '@/hooks/Mapper/components/ui-kit';

import { useMapCheckPermissions } from '@/hooks/Mapper/mapRootProvider/hooks/api';
import { UserPermission } from '@/hooks/Mapper/types/permissions.ts';
import { TopSearch } from '@/hooks/Mapper/components/mapRootContent/components/TopSearch';
// import { DebugComponent } from '@/hooks/Mapper/components/mapRootContent/components/RightBar/DebugComponent.tsx';

interface RightBarProps {
  onShowOnTheMap?: () => void;
  onShowMapSettings?: () => void;
  onShowTrackingDialog?: () => void;
  additionalContent?: ReactNode;
}

export const RightBar = ({
  onShowOnTheMap,
  onShowMapSettings,
  onShowTrackingDialog,
  additionalContent,
}: RightBarProps) => {
  const {
    storedSettings: { interfaceSettings, setInterfaceSettings },
  } = useMapRootState();

  const canTrackCharacters = useMapCheckPermissions([UserPermission.TRACK_CHARACTER]);

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
        'flex flex-col items-center justify-between pt-1',
      )}
    >
      <div className="flex flex-col gap-2 items-center mt-1">
        {canTrackCharacters && (
          <>
            <WdTooltipWrapper content="Tracking status" position={TooltipPosition.left}>
              <button
                className="btn bg-transparent text-gray-400 hover:text-white border-transparent hover:bg-transparent py-2 h-auto min-h-auto"
                type="button"
                onClick={onShowTrackingDialog}
                id="show-tracking-button"
              >
                <i className="pi pi-user-plus"></i>
              </button>
            </WdTooltipWrapper>

            <div className="flex flex-col gap-1">
              <TopSearch
                customBtn={open => (
                  <WdTooltipWrapper content="Show on the map" position={TooltipPosition.left}>
                    <button
                      className="btn bg-transparent text-gray-400 hover:text-white border-transparent hover:bg-transparent py-2 h-auto min-h-auto"
                      type="button"
                      onClick={open}
                    >
                      <i className="pi pi-search"></i>
                    </button>
                  </WdTooltipWrapper>
                )}
              />

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
          </>
        )}
        {additionalContent}
      </div>

      <div className="flex flex-col items-center mb-2 gap-1">
        {/* TODO - do not delete this code needs for debug */}
        {/*<DebugComponent />*/}

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
