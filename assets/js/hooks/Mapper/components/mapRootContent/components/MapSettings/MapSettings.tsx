import styles from './MapSettings.module.scss';
import { Dialog } from 'primereact/dialog';
import { useCallback, useRef, useState } from 'react';
import { TabPanel, TabView } from 'primereact/tabview';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { OutCommand } from '@/hooks/Mapper/types';
import {
  CONNECTIONS_CHECKBOXES_PROPS,
  SIGNATURES_CHECKBOXES_PROPS,
  SYSTEMS_CHECKBOXES_PROPS,
  THEME_SETTING,
  UI_CHECKBOXES_PROPS,
} from './constants.ts';
import {
  MapSettingsProvider,
  useMapSettings,
} from '@/hooks/Mapper/components/mapRootContent/components/MapSettings/MapSettingsProvider.tsx';
import { WidgetsSettings } from './components/WidgetsSettings';
import { CommonSettings } from './components/CommonSettings';
import { SettingsListItem } from './types.ts';

export interface MapSettingsProps {
  visible: boolean;
  onHide: () => void;
}

export const MapSettingsComp = ({ visible, onHide }: MapSettingsProps) => {
  const [activeIndex, setActiveIndex] = useState(0);
  const { outCommand } = useMapRootState();

  const { renderSettingItem, setUserRemoteSettings } = useMapSettings();

  const refVars = useRef({ outCommand, onHide, visible });
  refVars.current = { outCommand, onHide, visible };

  const handleShow = useCallback(async () => {
    const { user_settings } = await refVars.current.outCommand({
      type: OutCommand.getUserSettings,
      data: null,
    });
    setUserRemoteSettings({
      ...user_settings,
    });
  }, [setUserRemoteSettings]);

  const handleHide = useCallback(() => {
    if (!refVars.current.visible) {
      return;
    }

    setActiveIndex(0);
    refVars.current.onHide();
  }, []);

  const renderSettingsList = (list: SettingsListItem[]) => {
    return list.map(renderSettingItem);
  };

  return (
    <Dialog
      header="Map user settings"
      visible
      draggable={false}
      style={{ width: '550px' }}
      onShow={handleShow}
      onHide={handleHide}
    >
      <div className="flex flex-col gap-3">
        <div className="flex flex-col gap-2">
          <TabView
            activeIndex={activeIndex}
            className="vertical-tabs-container"
            onTabChange={e => setActiveIndex(e.index)}
          >
            <TabPanel header="Common" headerClassName={styles.verticalTabHeader}>
              <CommonSettings />
            </TabPanel>

            <TabPanel header="Systems" headerClassName={styles.verticalTabHeader}>
              <div className="w-full h-full flex flex-col gap-1">{renderSettingsList(SYSTEMS_CHECKBOXES_PROPS)}</div>
            </TabPanel>

            <TabPanel header="Connections" headerClassName={styles.verticalTabHeader}>
              {renderSettingsList(CONNECTIONS_CHECKBOXES_PROPS)}
            </TabPanel>

            <TabPanel header="Signatures" headerClassName={styles.verticalTabHeader}>
              {renderSettingsList(SIGNATURES_CHECKBOXES_PROPS)}
            </TabPanel>

            <TabPanel header="User Interface" headerClassName={styles.verticalTabHeader}>
              {renderSettingsList(UI_CHECKBOXES_PROPS)}
            </TabPanel>

            <TabPanel header="Widgets" className="h-full" headerClassName={styles.verticalTabHeader}>
              <WidgetsSettings />
            </TabPanel>

            <TabPanel header="Theme" headerClassName={styles.verticalTabHeader}>
              {renderSettingItem(THEME_SETTING)}
            </TabPanel>
          </TabView>
        </div>
      </div>
    </Dialog>
  );
};

export const MapSettings = (props: MapSettingsProps) => {
  return (
    <MapSettingsProvider>
      <MapSettingsComp {...props} />
    </MapSettingsProvider>
  );
};
