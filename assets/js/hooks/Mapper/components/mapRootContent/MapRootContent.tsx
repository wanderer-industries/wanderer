import Topbar from '@/hooks/Mapper/components/topbar/Topbar.tsx';
import { MapInterface } from '@/hooks/Mapper/components/mapInterface/MapInterface.tsx';
import Layout from '@/hooks/Mapper/components/layout/Layout.tsx';
import { MapWrapper } from '@/hooks/Mapper/components/mapWrapper/MapWrapper.tsx';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback, useState } from 'react';
import { OnTheMap, RightBar } from '@/hooks/Mapper/components/mapRootContent/components';
import { MapContextMenu } from '@/hooks/Mapper/components/mapRootContent/components/MapContextMenu/MapContextMenu.tsx';
import { useSkipContextMenu } from '@/hooks/Mapper/hooks/useSkipContextMenu';
import { MapSettings } from '@/hooks/Mapper/components/mapRootContent/components/MapSettings';
import { CharacterActivity } from '@/hooks/Mapper/components/mapRootContent/components/CharacterActivity';
import { useCharacterActivityHandlers } from './hooks/useCharacterActivityHandlers';
import { TrackingDialog } from '@/hooks/Mapper/components/mapRootContent/components/TrackingDialog';
import { useMapEventListener } from '@/hooks/Mapper/events';
import { Commands } from '@/hooks/Mapper/types';
import { PingsInterface } from '@/hooks/Mapper/components/mapInterface/components';
import { OldSettingsDialog } from '@/hooks/Mapper/components/mapRootContent/components/OldSettingsDialog.tsx';
import { TopSearch } from '@/hooks/Mapper/components/mapRootContent/components/TopSearch';

export interface MapRootContentProps {}

// eslint-disable-next-line no-empty-pattern
export const MapRootContent = ({}: MapRootContentProps) => {
  const {
    storedSettings: { interfaceSettings, isReady, hasOldSettings },
    data,
  } = useMapRootState();
  const { isShowMenu } = interfaceSettings;
  const { showCharacterActivity } = data;
  const { handleHideCharacterActivity } = useCharacterActivityHandlers();

  const themeClass = `${interfaceSettings.theme ?? 'default'}-theme`;

  const [showOnTheMap, setShowOnTheMap] = useState(false);
  const [showMapSettings, setShowMapSettings] = useState(false);
  const [showTrackingDialog, setShowTrackingDialog] = useState(false);

  /* Important Notice - this solution needs for use one instance of MapInterface */
  const mapInterface = isReady ? <MapInterface /> : null;

  const handleShowOnTheMap = useCallback(() => setShowOnTheMap(true), []);
  const handleShowMapSettings = useCallback(() => setShowMapSettings(true), []);
  const handleShowTrackingDialog = useCallback(() => setShowTrackingDialog(true), []);

  useMapEventListener(event => {
    if (event.name === Commands.showTracking) {
      setShowTrackingDialog(true);
      return true;
    }
  });

  useSkipContextMenu();

  return (
    <div className={themeClass}>
      <Layout map={<MapWrapper />}>
        {!isShowMenu ? (
          <div className="absolute top-0 left-14 w-[calc(100%-3.5rem)] h-[calc(100%-3.5rem)] pointer-events-none">
            <div className="absolute top-0 left-0 w-[calc(100%-3.5rem)] h-full pointer-events-none">
              <Topbar />
              {mapInterface}
            </div>
            <div className="absolute top-0 right-0 w-14 h-[calc(100%+3.5rem)] pointer-events-auto">
              <RightBar
                onShowOnTheMap={handleShowOnTheMap}
                onShowMapSettings={handleShowMapSettings}
                onShowTrackingDialog={handleShowTrackingDialog}
                additionalContent={<PingsInterface hasLeftOffset />}
              />
            </div>
          </div>
        ) : (
          <div className="absolute top-0 left-14 w-[calc(100%-3.5rem)] h-[calc(100%-3.5rem)] pointer-events-none">
            <Topbar>
              <div className="flex items-center ml-1">
                <TopSearch />
                <PingsInterface />
                <MapContextMenu
                  onShowOnTheMap={handleShowOnTheMap}
                  onShowMapSettings={handleShowMapSettings}
                  onShowTrackingDialog={handleShowTrackingDialog}
                />
              </div>
            </Topbar>
            {mapInterface}
          </div>
        )}
        <OnTheMap show={showOnTheMap} onHide={() => setShowOnTheMap(false)} />
        {showMapSettings && <MapSettings visible={showMapSettings} onHide={() => setShowMapSettings(false)} />}
        {showCharacterActivity && (
          <CharacterActivity visible={showCharacterActivity} onHide={handleHideCharacterActivity} />
        )}
        {showTrackingDialog && (
          <TrackingDialog visible={showTrackingDialog} onHide={() => setShowTrackingDialog(false)} />
        )}

        {hasOldSettings && <OldSettingsDialog />}
      </Layout>
    </div>
  );
};
