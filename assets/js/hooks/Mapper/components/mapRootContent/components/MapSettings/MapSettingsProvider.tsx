import { createContext, ReactNode, useCallback, useContext, useMemo, useRef } from 'react';
import {
  SettingsListItem,
  UserSettings,
  UserSettingsRemote,
} from '@/hooks/Mapper/components/mapRootContent/components/MapSettings/types.ts';
import { UserSettingsRemoteList } from '@/hooks/Mapper/constants/userSettings.ts';
import { OutCommand } from '@/hooks/Mapper/types';
import { PrettySwitchbox } from '@/hooks/Mapper/components/mapRootContent/components/MapSettings/components';
import { Dropdown } from 'primereact/dropdown';
import { InputText } from 'primereact/inputtext';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { WithChildren } from '@/hooks/Mapper/types/common.ts';
import { FormatTemplateInput } from '@/hooks/Mapper/components/mapRootContent/components/MapSettings/components/FormatTemplateInput.tsx';
import { SystemLabelDefinition } from '@/hooks/Mapper/constants/labels.ts';

export type SettingValue = boolean | string | Record<string, string> | SystemLabelDefinition[];

type MapSettingsContextType = {
  renderSettingItem: (item: SettingsListItem) => ReactNode;
  updateSetting: (prop: keyof UserSettings, value: SettingValue) => Promise<void>;
  setUserRemoteSettings: (settings: UserSettingsRemote) => void;
  settings: UserSettings;
};

const MapSettingsContext = createContext<MapSettingsContextType | undefined>(undefined);

export const MapSettingsProvider = ({ children }: WithChildren) => {
  const {
    outCommand,
    storedSettings: { interfaceSettings, setInterfaceSettings },
    userRemoteSettings: { userRemoteSettings, setUserRemoteSettings },
  } = useMapRootState();

  const mergedSettings: UserSettings = useMemo(() => {
    return {
      ...userRemoteSettings,
      ...interfaceSettings,
    };
  }, [userRemoteSettings, interfaceSettings]);

  const refVars = useRef({
    mergedSettings,
    userRemoteSettings,
    interfaceSettings,
    outCommand,
    setInterfaceSettings,
    setUserRemoteSettings,
  });
  refVars.current = {
    mergedSettings,
    userRemoteSettings,
    interfaceSettings,
    outCommand,
    setInterfaceSettings,
    setUserRemoteSettings,
  };

  const handleSettingChange = useCallback(
    async (prop: keyof UserSettings, value: SettingValue) => {
      const { userRemoteSettings, interfaceSettings, outCommand, setInterfaceSettings, setUserRemoteSettings } =
        refVars.current;

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
    [],
  );

  const renderSettingItem = useCallback(
    (item: SettingsListItem) => {
      if (item.dependsOn) {
        const dependsOnValue = refVars.current.mergedSettings[item.dependsOn];
        if (!dependsOnValue) {
          return null;
        }
      }

      const currentValue = refVars.current.mergedSettings[item.prop];

      if (item.type === 'checkbox') {
        return (
          <PrettySwitchbox
            key={item.prop.toString()}
            label={item.label}
            checked={!!currentValue}
            setChecked={checked => handleSettingChange(item.prop, checked)}
          />
        );
      }

      if (item.type === 'dropdown' && item.options) {
        return (
          <div key={item.prop.toString()} className="grid grid-cols-[auto_1fr_auto] items-center">
            <label className="text-[var(--gray-200)] text-[13px] select-none">{item.label}:</label>
            <div className="border-b-2 border-dotted border-[#3f3f3f] h-px mx-3" />
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

      if (item.type === 'template') {
        return (
          <FormatTemplateInput
            key={item.prop.toString()}
            label={item.label}
            value={(currentValue as string) || ''}
            placeholder={item.placeholder}
            helperText={item.helperText}
            onChange={value => handleSettingChange(item.prop, value)}
          />
        );
      }

      if (item.type === 'text') {
        return (
          <div key={item.prop.toString()} className="flex flex-col gap-1 w-full mt-2 mb-2">
            {item.label && <label className="text-[var(--gray-200)] text-[13px] select-none">{item.label}</label>}
            <InputText
              className="text-sm w-full"
              defaultValue={(currentValue as string) || ''}
              onBlur={e => handleSettingChange(item.prop, e.target.value)}
              placeholder={item.placeholder}
            />
            {item.helperText && <small className="text-gray-400 text-xs mt-1">{item.helperText}</small>}
          </div>
        );
      }

      return null;
    },
    [handleSettingChange],
  );

  return (
    <MapSettingsContext.Provider
      value={{ renderSettingItem, updateSetting: handleSettingChange, setUserRemoteSettings, settings: mergedSettings }}
    >
      {children}
    </MapSettingsContext.Provider>
  );
};

export const useMapSettings = () => {
  const context = useContext(MapSettingsContext);
  if (!context) {
    throw new Error('useMapSettings must be used within a MapSettingsProvider');
  }
  return context;
};
