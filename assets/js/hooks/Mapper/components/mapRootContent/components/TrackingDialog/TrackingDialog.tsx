import { useEffect, useRef, useState } from 'react';
import { Dialog } from 'primereact/dialog';
import { TabPanel, TabView } from 'primereact/tabview';
import { TrackingSettings } from './TrackingSettings.tsx';
import { TrackingCharactersList } from './TrackingCharactersList.tsx';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { TrackingProvider, useTracking } from './TrackingProvider.tsx';

interface TrackingDialogProps {
  visible: boolean;
  onHide: () => void;
}

const TrackingDialogComp = ({ visible, onHide }: TrackingDialogProps) => {
  const [activeIndex, setActiveIndex] = useState(0);
  const { outCommand } = useMapRootState();
  const { loadTracking } = useTracking();

  const refVars = useRef({ outCommand });
  refVars.current = { outCommand };

  useEffect(() => {
    if (!visible) {
      return;
    }

    loadTracking();
  }, [loadTracking, visible]);

  return (
    <Dialog
      header={
        <div className="dialog-header">
          <span className="pointer-events-none">Track & Follow</span>
        </div>
      }
      draggable={false}
      resizable={false}
      visible={visible}
      onHide={onHide}
      className="w-[640px] h-[400px] text-text-color min-h-0"
    >
      <TabView
        className="vertical-tabs-container h-full [&_.p-tabview-panels]:!pr-0"
        activeIndex={activeIndex}
        onTabChange={e => setActiveIndex(e.index)}
        renderActiveOnly={false}
      >
        <TabPanel header="Tracking" contentClassName="h-full">
          <TrackingCharactersList />
        </TabPanel>
        <TabPanel header="Follow & Settings">
          <TrackingSettings />
        </TabPanel>
      </TabView>
    </Dialog>
  );
};

export const TrackingDialog = (props: TrackingDialogProps) => {
  return (
    <TrackingProvider>
      <TrackingDialogComp {...props} />
    </TrackingProvider>
  );
};
