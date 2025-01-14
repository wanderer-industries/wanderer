import styles from './MapSettings.module.scss';
import { Dialog } from 'primereact/dialog';
import { useCallback, useMemo, useState } from 'react';
import { TabPanel, TabView } from 'primereact/tabview';
import { PrettySwitchbox } from './components';
import { InterfaceStoredSettingsProps, useMapRootState, InterfaceStoredSettings } from '@/hooks/Mapper/mapRootProvider';
import { OutCommand } from '@/hooks/Mapper/types';
import { Dropdown } from 'primereact/dropdown';
import { WidgetsSettings } from '@/hooks/Mapper/components/mapRootContent/components/MapSettings/components/WidgetsSettings/WidgetsSettings.tsx';

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

type SettingsListItem = {
  prop: keyof UserSettings;
  label: string;
  type: 'checkbox' | 'dropdown';
  options?: { label: string; value: string }[];
};

const COMMON_CHECKBOXES_PROPS: SettingsListItem[] = [
  {
    prop: InterfaceStoredSettingsProps.isShowMinimap,
    label: 'Show Minimap',
    type: 'checkbox',
  },
];

const SYSTEMS_CHECKBOXES_PROPS: SettingsListItem[] = [
  {
    prop: InterfaceStoredSettingsProps.isShowKSpace,
    label: 'Highlight Low/High-security systems',
    type: 'checkbox',
  },
  {
    prop: UserSettingsRemoteProps.select_on_spash,
    label: 'Auto-select splashed',
    type: 'checkbox',
  },
];

const SIGNATURES_CHECKBOXES_PROPS: SettingsListItem[] = [
  {
    prop: UserSettingsRemoteProps.link_signature_on_splash,
    label: 'Link signature on splash',
    type: 'checkbox',
  },
  {
    prop: InterfaceStoredSettingsProps.isShowUnsplashedSignatures,
    label: 'Show unsplashed signatures',
    type: 'checkbox',
  },
];

const CONNECTIONS_CHECKBOXES_PROPS: SettingsListItem[] = [
  {
    prop: UserSettingsRemoteProps.delete_connection_with_sigs,
    label: 'Delete connections to linked signatures',
    type: 'checkbox',
  },
  {
    prop: InterfaceStoredSettingsProps.isThickConnections,
    label: 'Thicker connections',
    type: 'checkbox',
  },
];

const UI_CHECKBOXES_PROPS: SettingsListItem[] = [
  {
    prop: InterfaceStoredSettingsProps.isShowMenu,
    label: 'Enable compact map menu bar',
    type: 'checkbox',
  },
  {
    prop: InterfaceStoredSettingsProps.isShowBackgroundPattern,
    label: 'Show background pattern',
    type: 'checkbox',
  },
  {
    prop: InterfaceStoredSettingsProps.isSoftBackground,
    label: 'Enable soft background',
    type: 'checkbox',
  },
];

const THEME_OPTIONS = [
  { label: 'Default', value: 'default' },
  { label: 'Pathfinder', value: 'pathfinder' },
];

const THEME_SETTING: SettingsListItem = {
  prop: 'theme',
  label: 'Theme',
  type: 'dropdown',
  options: THEME_OPTIONS,
};

export const MapSettings = ({ show, onHide }: MapSettingsProps) => {
  const [activeIndex, setActiveIndex] = useState(0);
  const { outCommand, interfaceSettings, setInterfaceSettings } = useMapRootState();
  const [userRemoteSettings, setUserRemoteSettings] = useState<UserSettingsRemote>({
    ...DEFAULT_REMOTE_SETTINGS,
  });

  const mergedSettings = useMemo(() => {
    return {
      ...userRemoteSettings,
      ...interfaceSettings,
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

  const handleSettingChange = useCallback(
    async (prop: keyof UserSettings, value: boolean | string) => {
      if (UserSettingsRemoteList.includes(prop as any)) {
        const newRemoteSettings = {
          ...userRemoteSettings,
          [prop]: value,
        };
        await outCommand({
          type: OutCommand.updateUserSettings,
          data: newRemoteSettings,
        });
        setUserRemoteSettings(newRemoteSettings);
      } else {
        setInterfaceSettings({
          ...interfaceSettings,
          [prop]: value,
        });
      }
    },
    [userRemoteSettings, interfaceSettings, outCommand, setInterfaceSettings],
  );

  const renderSettingItem = (item: SettingsListItem) => {
    const currentValue = mergedSettings[item.prop];

    if (item.type === 'checkbox') {
      return (
        <PrettySwitchbox
          key={item.prop}
          label={item.label}
          checked={!!currentValue}
          setChecked={checked => handleSettingChange(item.prop, checked)}
        />
      );
    }

    if (item.type === 'dropdown' && item.options) {
      return (
        <div key={item.prop} className="flex items-center gap-2 mt-2">
          <label className="text-sm">{item.label}:</label>
          <Dropdown
            className="text-sm"
            value={currentValue}
            options={item.options}
            onChange={e => handleSettingChange(item.prop, e.value)}
            placeholder="Select a theme"
          />
        </div>
      );
    }

    return null;
  };

  const renderSettingsList = (list: SettingsListItem[]) => {
    return list.map(renderSettingItem);
  };

  return (
    <Dialog
      header="Map user settings"
      visible={show}
      draggable={false}
      style={{ width: '550px' }}
      onShow={handleShow}
      onHide={() => {
        if (!show) return;
        setActiveIndex(0);
        onHide();
      }}
    >
      <div className="flex flex-col gap-3">
        <div className="flex flex-col gap-2">
          <div className={styles.verticalTabsContainer}>
            <TabView activeIndex={activeIndex} onTabChange={e => setActiveIndex(e.index)}>
              <TabPanel header="Common" headerClassName={styles.verticalTabHeader}>
                <div className="w-full h-full flex flex-col gap-1">{renderSettingsList(COMMON_CHECKBOXES_PROPS)}</div>
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
      </div>
    </Dialog>
  );
};
