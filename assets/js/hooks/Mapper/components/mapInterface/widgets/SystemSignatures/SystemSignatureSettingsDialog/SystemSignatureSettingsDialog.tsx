import { Dialog } from 'primereact/dialog';
import { useCallback, useState } from 'react';
import { Button } from 'primereact/button';
import { Checkbox } from 'primereact/checkbox';
import { TabPanel, TabView } from 'primereact/tabview';
import styles from './SystemSignatureSettingsDialog.module.scss';

export type Setting = { key: string; name: string; value: boolean; isFilter?: boolean };

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

  const filterSettings = settings.filter(setting => setting.isFilter);
  const userSettings = settings.filter(setting => !setting.isFilter);

  const handleSettingsChange = (key: string) => {
    setSettings(prevState => prevState.map(item => (item.key === key ? { ...item, value: !item.value } : item)));
  };

  const handleSave = useCallback(() => {
    onSave(settings);
  }, [onSave, settings]);

  return (
    <Dialog header="System Signatures Settings" visible={true} onHide={onCancel} className="w-full max-w-lg">
      <div className="flex flex-col gap-3">
        <div className="flex flex-col gap-2">
          <div className={styles.verticalTabsContainer}>
            <TabView
              activeIndex={activeIndex}
              onTabChange={e => setActiveIndex(e.index)}
              className={styles.verticalTabView}
            >
              <TabPanel header="Filters" headerClassName={styles.verticalTabHeader}>
                <div className="w-full h-full flex flex-col gap-1">
                  {filterSettings.map(setting => {
                    return (
                      <div key={setting.key} className="flex items-center">
                        <Checkbox
                          inputId={setting.key}
                          checked={setting.value}
                          onChange={() => handleSettingsChange(setting.key)}
                        />
                        <label htmlFor={setting.key} className="ml-2">
                          {setting.name}
                        </label>
                      </div>
                    );
                  })}
                </div>
              </TabPanel>
              <TabPanel header="User Interface" headerClassName={styles.verticalTabHeader}>
                <div className="w-full h-full flex flex-col gap-1">
                  {userSettings.map(setting => {
                    return (
                      <div key={setting.key} className="flex items-center">
                        <Checkbox
                          inputId={setting.key}
                          checked={setting.value}
                          onChange={() => handleSettingsChange(setting.key)}
                        />
                        <label htmlFor={setting.key} className="ml-2">
                          {setting.name}
                        </label>
                      </div>
                    );
                  })}
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
