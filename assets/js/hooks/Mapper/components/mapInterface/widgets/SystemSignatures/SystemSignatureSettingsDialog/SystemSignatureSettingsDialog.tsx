import { Dialog } from 'primereact/dialog';
import { useCallback, useState } from 'react';
import { Button } from 'primereact/button';
import { Checkbox } from 'primereact/checkbox';

export type Setting = { key: string; name: string; value: boolean };

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
  const [settings, setSettings] = useState<Setting[]>(defaultSettings);

  const handleSettingsChange = (key: string) => {
    setSettings(prevState => prevState.map(item => (item.key === key ? { ...item, value: !item.value } : item)));
  };

  const handleSave = useCallback(() => {
    onSave(settings);
  }, [onSave, settings]);

  return (
    <Dialog header="Filter signatures" visible draggable={false} style={{ width: '300px' }} onHide={onCancel}>
      <div className="flex flex-col gap-3">
        <div className="flex flex-col gap-2">
          {settings.map(setting => {
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

        <div className="flex gap-2 justify-end">
          <Button onClick={handleSave} outlined size="small" label="Save"></Button>
        </div>
      </div>
    </Dialog>
  );
};
