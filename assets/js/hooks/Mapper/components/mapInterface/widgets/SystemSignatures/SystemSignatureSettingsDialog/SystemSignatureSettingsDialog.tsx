import { Dialog } from 'primereact/dialog';
import { useCallback, useState } from 'react';
import { TabPanel, TabView } from 'primereact/tabview';
import { PrettySwitchbox } from '@/hooks/Mapper/components/mapRootContent/components/MapSettings/components';
import { Dropdown } from 'primereact/dropdown';
import {
  Setting,
  SettingsTypes,
  SIGNATURE_SETTINGS,
} from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/constants.ts';
import { SignatureSettingsType } from '@/hooks/Mapper/constants/signatures.ts';
import { WdButton } from '@/hooks/Mapper/components/ui-kit';

interface SystemSignatureSettingsDialogProps {
  settings: SignatureSettingsType;
  onSave: (settings: SignatureSettingsType) => void;
  onCancel: () => void;
}

export const SystemSignatureSettingsDialog = ({
  settings: defaultSettings,
  onSave,
  onCancel,
}: SystemSignatureSettingsDialogProps) => {
  const [activeIndex, setActiveIndex] = useState(0);
  const [settings, setSettings] = useState<SignatureSettingsType>(defaultSettings);

  const handleSettingsChange = ({ key, type }: Setting, value?: unknown) => {
    setSettings(prev => {
      switch (type) {
        case SettingsTypes.dropdown:
          return { ...prev, [key]: value };
        case SettingsTypes.flag:
          return { ...prev, [key]: !prev[key] };
      }
      return prev;
    });
  };

  const handleSave = useCallback(() => {
    onSave(settings);
  }, [onSave, settings]);

  const renderSetting = (setting: Setting) => {
    const val = settings[setting.key];
    if (setting.options) {
      return (
        <div key={setting.key} className="flex items-center justify-between gap-2 mb-2">
          <label className="text-[#b8b8b8] text-[13px] select-none">{setting.name}</label>
          <Dropdown
            value={val}
            options={setting.options}
            onChange={e => handleSettingsChange(setting, e.value)}
            className="w-40"
          />
        </div>
      );
    }

    return (
      <PrettySwitchbox
        key={setting.key}
        label={setting.name}
        checked={!!val}
        setChecked={() => handleSettingsChange(setting)}
      />
    );
  };

  return (
    <Dialog header="System Signatures Settings" visible={true} onHide={onCancel} className="w-full max-w-lg h-[500px]">
      <div className="flex flex-col gap-3 justify-between h-full">
        <div className="flex flex-col gap-2">
          <TabView
            activeIndex={activeIndex}
            onTabChange={e => setActiveIndex(e.index)}
            className="vertical-tabs-container"
          >
            <TabPanel header="Filters">
              <div className="w-full h-full flex flex-col gap-1">
                {SIGNATURE_SETTINGS.filterFlags.map(renderSetting)}
              </div>
            </TabPanel>
            <TabPanel header="User Interface">
              <div className="w-full h-full flex flex-col gap-1">
                {SIGNATURE_SETTINGS.uiFlags.map(renderSetting)}
                <div className="my-2 border-t border-stone-700/50"></div>
                {SIGNATURE_SETTINGS.uiOther.map(renderSetting)}
              </div>
            </TabPanel>
          </TabView>
        </div>

        <div className="flex gap-2 justify-end">
          <WdButton onClick={handleSave} outlined size="small" label="Save" />
        </div>
      </div>
    </Dialog>
  );
};
