import { useEffect, useRef, useState } from 'react';
import { Dialog } from 'primereact/dialog';
import { TabPanel, TabView } from 'primereact/tabview';
import { TrackingSettings } from './TrackingSettings.tsx';
import { TrackingCharactersList } from '@/hooks/Mapper/components/mapRootContent/components/TrackingDialog/TrackingCharactersList.tsx';
import { OutCommand } from '@/hooks/Mapper/types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

interface TrackingDialogProps {
  visible: boolean;
  onHide: () => void;
}

export const TrackingDialog = ({ visible, onHide }: TrackingDialogProps) => {
  const [activeIndex, setActiveIndex] = useState(0);
  const { outCommand } = useMapRootState();

  const refVars = useRef({ outCommand });
  refVars.current = { outCommand };

  useEffect(() => {
    if (!visible) {
      return;
    }

    refVars.current.outCommand({
      type: OutCommand.showTracking,
      data: {},
    });
  }, [visible]);

  return (
    <Dialog
      header={
        <div className="dialog-header">
          <span>Track & Follow</span>
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
