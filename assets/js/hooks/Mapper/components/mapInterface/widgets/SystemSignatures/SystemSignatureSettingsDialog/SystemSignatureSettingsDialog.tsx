import { Dialog } from 'primereact/dialog';
import { useCallback, useState } from 'react';
import { Button } from 'primereact/button';
import { TabPanel, TabView } from 'primereact/tabview';
import styles from './SystemSignatureSettingsDialog.module.scss';
import { PrettySwitchbox } from '@/hooks/Mapper/components/mapRootContent/components/MapSettings/components';
import { Dropdown } from 'primereact/dropdown';

export type Setting = {
  key: string;
  name: string;
  value: boolean | number;
  isFilter?: boolean;
  options?: { label: string; value: number }[];
};

export const COSMIC_SIGNATURE = 'Cosmic Signature';
export const COSMIC_ANOMALY = 'Cosmic Anomaly';
export const DEPLOYABLE = 'Deployable';
export const STRUCTURE = 'Structure';
export const STARBASE = 'Starbase';
export const SHIP = 'Ship';
export const DRONE = 'Drone';

interface SystemSignatureSettingsDialogProps {
  settings: Setting[];
  onSave: (settings: Setting[]) => void;
  onCancel: () => void;
}

export const SystemSignatureSettingsDialog = ({
  settings: defaultSettings,
  onSave,
  onCancel,
}: SystemSignatureSettingsDialogProps) => {
  const [activeIndex, setActiveIndex] = useState(0);
  const [settings, setSettings] = useState<Setting[]>(defaultSettings);

  // Debug log to check settings
  console.log('Settings in dialog:', settings);

  const filterSettings = settings.filter(setting => setting.isFilter);
  const userSettings = settings.filter(setting => !setting.isFilter);

  const handleSettingsChange = (key: string) => {
    setSettings(prevState =>
      prevState.map(item =>
        item.key === key ? { ...item, value: typeof item.value === 'boolean' ? !item.value : item.value } : item,
      ),
    );
  };

  const handleDropdownChange = (key: string, value: number) => {
    setSettings(prevState => prevState.map(item => (item.key === key ? { ...item, value } : item)));
  };

  const handleSave = useCallback(() => {
    onSave(settings);
  }, [onSave, settings]);

  const renderSetting = (setting: Setting) => {
    // Debug log to check each setting
    console.log('Rendering setting:', setting);
    if (setting.options) {
      return (
        <div key={setting.key} className="flex items-center justify-between gap-2 mb-2">
          <label className="text-[#b8b8b8] text-[13px] select-none">{setting.name}</label>
          <Dropdown
            value={setting.value}
            options={setting.options.map(opt => ({
              ...opt,
              label: opt.label.split(' ')[0], // Just take the first part (e.g., "0s" from "Immediate (0s)")
            }))}
            onChange={e => handleDropdownChange(setting.key, e.value)}
            className="w-40"
          />
        </div>
      );
    }

    return (
      <PrettySwitchbox
        key={setting.key}
        label={setting.name}
        checked={!!setting.value}
        setChecked={() => handleSettingsChange(setting.key)}
      />
    );
  };

  return (
    <Dialog header="System Signatures Settings" visible={true} onHide={onCancel} className="w-full max-w-lg h-[500px]">
      <div className="flex flex-col gap-3 justify-between h-full">
        <div className="flex flex-col gap-2">
          <div className={styles.verticalTabsContainer}>
            <TabView
              activeIndex={activeIndex}
              onTabChange={e => setActiveIndex(e.index)}
              className={styles.verticalTabView}
            >
              <TabPanel header="Filters" headerClassName={styles.verticalTabHeader}>
                <div className="w-full h-full flex flex-col gap-1">{filterSettings.map(renderSetting)}</div>
              </TabPanel>
              <TabPanel header="User Interface" headerClassName={styles.verticalTabHeader}>
                <div className="w-full h-full flex flex-col gap-1">
                  {userSettings.filter(setting => !setting.options).map(renderSetting)}
                  {userSettings.some(setting => setting.options) && (
                    <div className="my-2 border-t border-stone-700/50"></div>
                  )}
                  {userSettings.filter(setting => setting.options).map(renderSetting)}
                </div>
              </TabPanel>
            </TabView>
          </div>
        </div>

        <div className="flex gap-2 justify-end">
          <Button onClick={handleSave} outlined size="small" label="Save"></Button>
        </div>
      </div>
    </Dialog>
  );
};
