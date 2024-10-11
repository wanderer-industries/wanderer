import Topbar from '@/hooks/Mapper/components/topbar/Topbar.tsx';
import { MapInterface } from '@/hooks/Mapper/components/mapInterface/MapInterface.tsx';
import Layout from '@/hooks/Mapper/components/layout/Layout.tsx';
import { MapWrapper } from '@/hooks/Mapper/components/mapWrapper/MapWrapper.tsx';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback, useState } from 'react';
import { OnTheMap, RightBar } from '@/hooks/Mapper/components/mapRootContent/components';
import { MapContextMenu } from '@/hooks/Mapper/components/mapRootContent/components/MapContextMenu/MapContextMenu.tsx';
import { useSkipContextMenu } from '@/hooks/Mapper/hooks/useSkipContextMenu';

export interface MapRootContentProps {}

// eslint-disable-next-line no-empty-pattern
export const MapRootContent = ({}: MapRootContentProps) => {
  const { mapRef, interfaceSettings } = useMapRootState();
  const { isShowMenu } = interfaceSettings;

  const [showOnTheMap, setShowOnTheMap] = useState(false);
  const mapInterface = <MapInterface />;

  const handleShowOnTheMap = useCallback(() => setShowOnTheMap(true), []);

  useSkipContextMenu();

  return (
    <Layout map={<MapWrapper refn={mapRef} />}>
      {!isShowMenu ? (
        <div className="absolute top-0 left-14 w-[calc(100%-3.5rem)] h-[calc(100%-3.5rem)] pointer-events-none">
          <div className="absolute top-0 left-0 w-[calc(100%-3.5rem)] h-full pointer-events-none">
            <Topbar />
            {mapInterface}
          </div>
          <div className="absolute top-0 right-0 w-14 h-[calc(100%+3.5rem)] pointer-events-auto">
            <RightBar onShowOnTheMap={handleShowOnTheMap} />
          </div>
        </div>
      ) : (
        <div className="absolute top-0 left-14 w-[calc(100%-3.5rem)] h-[calc(100%-3.5rem)] pointer-events-none">
          <Topbar>
            <MapContextMenu onShowOnTheMap={handleShowOnTheMap} />
          </Topbar>
          {mapInterface}
        </div>
      )}
      <OnTheMap show={showOnTheMap} onHide={() => setShowOnTheMap(false)} />
    </Layout>
  );
};
