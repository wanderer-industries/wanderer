import classes from './RightBar.module.scss';
import clsx from 'clsx';
import { ReactNode, useCallback, useEffect, useRef, useState } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { TooltipPosition } from '@/hooks/Mapper/components/ui-kit';
import { Toast } from 'primereact/toast';

import { useMapCheckPermissions } from '@/hooks/Mapper/mapRootProvider/hooks/api';
import { OutCommand, UserPermission } from '@/hooks/Mapper/types';
import { TopSearch } from '@/hooks/Mapper/components/mapRootContent/components/TopSearch';
import { callToastError, callToastSuccess } from '@/hooks/Mapper/helpers';
// import { DebugComponent } from '@/hooks/Mapper/components/mapRootContent/components/RightBar/DebugComponent.tsx';

const AUTO_LAYOUT_PERMISSIONS: UserPermission[] = [UserPermission.ADMIN_MAP, UserPermission.UPDATE_SYSTEM];
const TRACKING_PERMISSIONS: UserPermission[] = [UserPermission.TRACK_CHARACTER];

interface LayoutSettingsStatus {
  available: boolean;
  enabled: boolean;
}

interface RunAutoLayoutResponse {
  success: boolean;
  error?: string;
}

export interface RightBarProps {
  onShowOnTheMap?: () => void;
  onShowMapSettings?: () => void;
  onShowTrackingDialog?: () => void;
  onShowWormholesReference?: () => void;
  onShowJumpPlanner?: () => void;
  additionalContent?: ReactNode;
}

export const RightBar = ({
  onShowOnTheMap,
  onShowMapSettings,
  onShowTrackingDialog,
  onShowWormholesReference,
  onShowJumpPlanner,
  additionalContent,
}: RightBarProps) => {
  const {
    storedSettings: { interfaceSettings, setInterfaceSettings },
    outCommand,
  } = useMapRootState();
  const toast = useRef<Toast | null>(null);
  const [showAutoLayout, setShowAutoLayout] = useState(false);
  const [autoLayoutRunning, setAutoLayoutRunning] = useState(false);

  const canTrackCharacters = useMapCheckPermissions(TRACKING_PERMISSIONS);
  const canRunAutoLayout = useMapCheckPermissions(AUTO_LAYOUT_PERMISSIONS);

  useEffect(() => {
    if (!canRunAutoLayout) {
      setShowAutoLayout(false);
      return;
    }

    void outCommand<LayoutSettingsStatus>({ type: OutCommand.getLayoutSettings, data: null })
      .then(({ available, enabled }) => setShowAutoLayout(available && enabled))
      .catch(() => setShowAutoLayout(false));
  }, [canRunAutoLayout, outCommand]);

  let kSpaceTooltip = 'Show highlighting Imperial Space';
  if (interfaceSettings.isShowKSpace) {
    kSpaceTooltip = 'Hide highlighting Imperial Space';
  }

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

  const runAutoLayout = useCallback(async () => {
    setAutoLayoutRunning(true);

    try {
      const response = await outCommand<RunAutoLayoutResponse>({ type: OutCommand.runAutoLayout, data: null });

      if (!response.success) {
        callToastError(toast.current, response.error ?? 'Unable to run auto layout');
        return;
      }

      callToastSuccess(toast.current, 'Map layout applied');
    } catch {
      callToastError(toast.current, 'Unable to run auto layout');
    } finally {
      setAutoLayoutRunning(false);
    }
  }, [outCommand]);

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

              <WdTooltipWrapper content="Wormholes Reference" position={TooltipPosition.left}>
                <button
                  className="btn bg-transparent text-gray-400 hover:text-white border-transparent hover:bg-transparent py-2 h-auto min-h-auto"
                  type="button"
                  onClick={onShowWormholesReference}
                >
                  <i className="pi pi-book"></i>
                </button>
              </WdTooltipWrapper>

              <WdTooltipWrapper content="Jump Planner" position={TooltipPosition.left}>
                <button
                  className="btn bg-transparent text-gray-400 hover:text-white border-transparent hover:bg-transparent py-2 h-auto min-h-auto"
                  type="button"
                  onClick={onShowJumpPlanner}
                  aria-label="Open Jump Planner"
                >
                  <i className="hero-jump-range-diagonal w-5 h-5 relative left-[-2px]" />
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

        {showAutoLayout && (
          <WdTooltipWrapper content="Auto layout" position={TooltipPosition.left}>
            <button
              className="btn bg-transparent text-sky-400 hover:text-white border-transparent hover:bg-transparent py-2 h-auto min-h-auto"
              type="button"
              onClick={() => void runAutoLayout()}
              disabled={autoLayoutRunning}
              aria-label="Run auto layout"
            >
              <i className={autoLayoutRunning ? 'pi pi-spinner pi-spin' : 'pi pi-sitemap'}></i>
            </button>
          </WdTooltipWrapper>
        )}

        <WdTooltipWrapper content="Map user settings" position={TooltipPosition.left}>
          <button
            className="btn bg-transparent text-gray-400 hover:text-white border-transparent hover:bg-transparent py-2 h-auto min-h-auto"
            type="button"
            onClick={onShowMapSettings}
          >
            <i className="pi pi-cog"></i>
          </button>
        </WdTooltipWrapper>

        <WdTooltipWrapper content={kSpaceTooltip} position={TooltipPosition.left}>
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
      <Toast ref={toast} />
    </div>
  );
};
