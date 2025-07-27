import { useEffect, useState, useCallback } from 'react';
import { Dialog } from 'primereact/dialog';
import { TabPanel, TabView } from 'primereact/tabview';
import { TrackingSettings } from './TrackingSettings.tsx';
import { TrackingCharactersList } from './TrackingCharactersList.tsx';
import { ReadyCharactersList } from './ReadyCharactersList.tsx';
import { TrackingProvider, useTracking } from './TrackingProvider.tsx';

interface TrackingDialogProps {
  visible: boolean;
  onHide: () => void;
}

const TrackingDialogContent = ({ visible, onHide }: TrackingDialogProps) => {
  const [activeIndex, setActiveIndex] = useState(0);
  const { loadTracking, trackingCharacters, ready, updateReady } = useTracking();

  useEffect(() => {
    if (visible) {
      loadTracking();
    }
  }, [visible, loadTracking]);

  const handleReadyChange = useCallback(
    (characterId: string, isReady: boolean) => {
      if (isReady) {
        if (ready.includes(characterId)) {
          return;
        }
        updateReady([...ready, characterId]);
        return;
      }
      updateReady(ready.filter(id => id !== characterId));
    },
    [ready, updateReady],
  );

  return (
    <Dialog
      header={<div className="dialog-header pointer-events-none">Track &amp; Follow</div>}
      draggable={false}
      resizable={false}
      visible={visible}
      onHide={onHide}
      className="w-[640px] h-[400px] min-h-0 text-text-color"
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
        <TabPanel header="Follow &amp; Settings">
          <TrackingSettings />
        </TabPanel>
        <TabPanel header="Ready" contentClassName="h-full">
          <ReadyCharactersList
            trackingCharacters={trackingCharacters}
            ready={ready}
            onReadyChange={handleReadyChange}
          />
        </TabPanel>
      </TabView>
    </Dialog>
  );
};

export const TrackingDialog = (props: TrackingDialogProps) => {
  return (
    <TrackingProvider>
      <TrackingDialogContent {...props} />
    </TrackingProvider>
  );
};
