import styles from './MapSettings.module.scss';
import { Dialog } from 'primereact/dialog';
import { useCallback, useMemo, useState } from 'react';
import { TabPanel, TabView } from 'primereact/tabview';
import { PrettySwitchbox } from './components';
import { InterfaceStoredSettings, InterfaceStoredSettingsProps, useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { OutCommand } from '@/hooks/Mapper/types';

export enum UserSettingsRemoteProps {
  link_signature_on_splash = 'link_signature_on_splash',
  select_on_spash = 'select_on_spash',
  delete_connection_with_sigs = 'delete_connection_with_sigs',
}

export const DEFAULT_REMOTE_SETTINGS = {
  [UserSettingsRemoteProps.link_signature_on_splash]: false,
  [UserSettingsRemoteProps.select_on_spash]: false,
  [UserSettingsRemoteProps.delete_connection_with_sigs]: false,
};

export const UserSettingsRemoteList = [
  UserSettingsRemoteProps.link_signature_on_splash,
  UserSettingsRemoteProps.select_on_spash,
  UserSettingsRemoteProps.delete_connection_with_sigs,
];

export type UserSettingsRemote = {
  link_signature_on_splash: boolean;
  select_on_spash: boolean;
  delete_connection_with_sigs: boolean;
};

export type UserSettings = UserSettingsRemote & InterfaceStoredSettings;

export interface MapSettingsProps {
  show: boolean;
  onHide: () => void;
}

type CheckboxesList = {
  prop: keyof UserSettings;
  label: string;
}[];

const COMMON_CHECKBOXES_PROPS: CheckboxesList = [
  { prop: InterfaceStoredSettingsProps.isShowMinimap, label: 'Show Minimap' },
];

const SYSTEMS_CHECKBOXES_PROPS: CheckboxesList = [
  { prop: InterfaceStoredSettingsProps.isShowKSpace, label: 'Highlight Low/High-security systems' },
  { prop: UserSettingsRemoteProps.select_on_spash, label: 'Auto-select splashed' },
];

const SIGNATURES_CHECKBOXES_PROPS: CheckboxesList = [
  { prop: UserSettingsRemoteProps.link_signature_on_splash, label: 'Link signature on splash' },
  { prop: InterfaceStoredSettingsProps.isShowUnsplashedSignatures, label: 'Show unsplashed signatures' },
];

const CONNECTIONS_CHECKBOXES_PROPS: CheckboxesList = [
  { prop: UserSettingsRemoteProps.delete_connection_with_sigs, label: 'Delete connections to linked signatures' },
];

const UI_CHECKBOXES_PROPS: CheckboxesList = [
  { prop: InterfaceStoredSettingsProps.isShowMenu, label: 'Enable compact map menu bar' },
  { prop: InterfaceStoredSettingsProps.isThickConnections, label: 'Thicker connections' },
];

export const MapSettings = ({ show, onHide }: MapSettingsProps) => {
  const [activeIndex, setActiveIndex] = useState(0);
  const { outCommand, interfaceSettings, setInterfaceSettings } = useMapRootState();
  const [userRemoteSettings, setUserRemoteSettings] = useState<UserSettingsRemote>({ ...DEFAULT_REMOTE_SETTINGS });

  const mergedSettings = useMemo(() => {
    return {
      ...interfaceSettings,
      ...userRemoteSettings,
    };
  }, [userRemoteSettings, interfaceSettings]);

  const handleShow = async () => {
    const { user_settings } = await outCommand({
      type: OutCommand.getUserSettings,
      data: null,
    });

    setUserRemoteSettings({
      ...user_settings,
    });
  };

  const handleChangeChecked = useCallback(
    (prop: keyof UserSettings) => async (checked: boolean) => {
      // @ts-ignore
      if (UserSettingsRemoteList.includes(prop)) {
        const newRemoteSettings = {
          ...userRemoteSettings,
          [prop]: checked,
        };

        await outCommand({
          type: OutCommand.updateUserSettings,
          data: newRemoteSettings,
        });

        setUserRemoteSettings(newRemoteSettings);
        return;
      }

      setInterfaceSettings({
        ...interfaceSettings,
        [prop]: checked,
      });
    },
    [interfaceSettings, outCommand, setInterfaceSettings, userRemoteSettings],
  );

  const renderCheckboxesList = (list: CheckboxesList) => {
    return list.map(x => {
      return (
        <PrettySwitchbox
          key={x.prop}
          label={x.label}
          checked={mergedSettings[x.prop]}
          setChecked={handleChangeChecked(x.prop)}
        />
      );
    });
  };

  return (
    <Dialog
      header="Map user settings"
      visible={show}
      draggable={false}
      style={{ width: '550px' }}
      onShow={handleShow}
      onHide={() => {
        if (!show) {
          return;
        }

        setActiveIndex(0);
        onHide();
      }}
    >
      <div className="flex flex-col gap-3">
        <div className="flex flex-col gap-2">
          <div className={styles.verticalTabsContainer}>
            <TabView
              activeIndex={activeIndex}
              onTabChange={e => setActiveIndex(e.index)}
              className={styles.verticalTabView}
            >
              <TabPanel header="Common" headerClassName={styles.verticalTabHeader}>
                <div className="w-full h-full flex flex-col gap-1">{renderCheckboxesList(COMMON_CHECKBOXES_PROPS)}</div>
              </TabPanel>
              <TabPanel header="Systems" headerClassName={styles.verticalTabHeader}>
                <div className="w-full h-full flex flex-col gap-1">
                  {renderCheckboxesList(SYSTEMS_CHECKBOXES_PROPS)}
                </div>
              </TabPanel>
              <TabPanel header="Connections" headerClassName={styles.verticalTabHeader}>
                {renderCheckboxesList(CONNECTIONS_CHECKBOXES_PROPS)}
              </TabPanel>
              <TabPanel header="Signatures" headerClassName={styles.verticalTabHeader}>
                {renderCheckboxesList(SIGNATURES_CHECKBOXES_PROPS)}
              </TabPanel>
              <TabPanel header="User Interface" headerClassName={styles.verticalTabHeader}>
                {renderCheckboxesList(UI_CHECKBOXES_PROPS)}
              </TabPanel>
            </TabView>
          </div>
        </div>
      </div>
    </Dialog>
  );
};
