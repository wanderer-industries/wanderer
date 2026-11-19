import styles from './MapSettings.module.scss';
import clsx from 'clsx';
import { Dialog } from 'primereact/dialog';
import { useCallback, useRef, useState } from 'react';
import { TabPanel, TabView } from 'primereact/tabview';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { GetUserSettingsResponse, OutCommand, UserPermission } from '@/hooks/Mapper/types';
import {
  CONNECTIONS_CHECKBOXES_PROPS,
  DEFAULT_REMOTE_SETTINGS,
  DOTLAN_BEHAVIOR_SETTING,
  SIGNATURES_CHECKBOXES_PROPS,
  SYSTEMS_CHECKBOXES_PROPS,
} from './constants.ts';
import {
  MapSettingsProvider,
  useMapSettings,
} from '@/hooks/Mapper/components/mapRootContent/components/MapSettings/MapSettingsProvider.tsx';
import { WidgetsSettings } from './components/WidgetsSettings';
import { CommonSettings } from './components/CommonSettings';
import { NotificationSettings } from './components/NotificationSettings.tsx';
import { BookmarksSettings } from './components/BookmarksSettings';
import { SettingsListItem } from './types.ts';
import { ImportExport } from './components/ImportExport.tsx';
import { ServerSettings } from './components/ServerSettings.tsx';
import { AdminSettings } from './components/AdminSettings.tsx';
import { useMapCheckPermissions } from '@/hooks/Mapper/mapRootProvider/hooks/api';

export interface MapSettingsProps {
  visible: boolean;
  onHide: () => void;
}

export const MapSettingsComp = ({ visible, onHide }: MapSettingsProps) => {
  const [activeIndex, setActiveIndex] = useState(0);
  const { outCommand } = useMapRootState();

  const { renderSettingItem, setUserRemoteSettings } = useMapSettings();
  const isAdmin = useMapCheckPermissions([UserPermission.ADMIN_MAP]);

  const refVars = useRef({ outCommand, onHide, visible });
  refVars.current = { outCommand, onHide, visible };

  const handleShow = useCallback(async () => {
    const res = await refVars.current.outCommand<GetUserSettingsResponse>({
      type: OutCommand.getUserSettings,
      data: null,
    });
    setUserRemoteSettings({
      ...DEFAULT_REMOTE_SETTINGS,
      ...res?.user_settings,
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
      className="w-[600px] h-[460px]"
      contentClassName="custom-scrollbar"
      onShow={handleShow}
      onHide={handleHide}
    >
      <div className="flex h-full min-w-0 flex-col gap-3 overflow-hidden">
        <div className="flex h-full min-w-0 flex-col gap-2 overflow-hidden">
          <TabView
            activeIndex={activeIndex}
            className={clsx('vertical-tabs-container h-full min-w-0 overflow-hidden', styles.tabViewContent)}
            onTabChange={e => setActiveIndex(e.index)}
          >
            <TabPanel header="Common" headerClassName={styles.verticalTabHeader}>
              <CommonSettings />
            </TabPanel>

            <TabPanel header="Notification" headerClassName={styles.verticalTabHeader}>
              <NotificationSettings />
            </TabPanel>

            <TabPanel header="Systems" headerClassName={styles.verticalTabHeader}>
              <div className="flex h-full w-full flex-col gap-1">
                {renderSettingsList(SYSTEMS_CHECKBOXES_PROPS)}
                <div className={clsx('mt-3 border-t pt-3', styles.dotlanSetting)}>
                  {renderSettingItem(DOTLAN_BEHAVIOR_SETTING)}
                </div>
              </div>
            </TabPanel>

            <TabPanel header="Connections" headerClassName={styles.verticalTabHeader}>
              {renderSettingsList(CONNECTIONS_CHECKBOXES_PROPS)}
            </TabPanel>

            <TabPanel header="Signatures" headerClassName={styles.verticalTabHeader}>
              {renderSettingsList(SIGNATURES_CHECKBOXES_PROPS)}
            </TabPanel>

            <TabPanel header="Bookmarks" className="h-full" headerClassName={styles.verticalTabHeader}>
              <BookmarksSettings />
            </TabPanel>

            <TabPanel header="Widgets" className="h-full" headerClassName={styles.verticalTabHeader}>
              <WidgetsSettings />
            </TabPanel>

            <TabPanel header="Import/Export" className="h-full" headerClassName={styles.verticalTabHeader}>
              <ImportExport />
            </TabPanel>

            <TabPanel header="Server Settings" className="h-full" headerClassName="color-warn">
              <ServerSettings />
            </TabPanel>

            {isAdmin && (
              <TabPanel header="Admin Settings" className="h-full" headerClassName="color-warn">
                <AdminSettings />
              </TabPanel>
            )}
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
