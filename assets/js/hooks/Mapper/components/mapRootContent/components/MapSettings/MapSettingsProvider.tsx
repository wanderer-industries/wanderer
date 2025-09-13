import {
  createContext,
  Dispatch,
  ReactNode,
  SetStateAction,
  useCallback,
  useContext,
  useMemo,
  useRef,
  useState,
} from 'react';
import {
  SettingsListItem,
  UserSettings,
  UserSettingsRemote,
} from '@/hooks/Mapper/components/mapRootContent/components/MapSettings/types.ts';
import {
  DEFAULT_REMOTE_SETTINGS,
  UserSettingsRemoteList,
} from '@/hooks/Mapper/components/mapRootContent/components/MapSettings/constants.ts';
import { OutCommand } from '@/hooks/Mapper/types';
import { PrettySwitchbox } from '@/hooks/Mapper/components/mapRootContent/components/MapSettings/components';
import { Dropdown } from 'primereact/dropdown';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { WithChildren } from '@/hooks/Mapper/types/common.ts';

type MapSettingsContextType = {
  renderSettingItem: (item: SettingsListItem) => ReactNode;
  setUserRemoteSettings: Dispatch<SetStateAction<UserSettingsRemote>>;
};

const MapSettingsContext = createContext<MapSettingsContextType | undefined>(undefined);

export const MapSettingsProvider = ({ children }: WithChildren) => {
  const {
    outCommand,
    storedSettings: { interfaceSettings, setInterfaceSettings },
  } = useMapRootState();

  const [userRemoteSettings, setUserRemoteSettings] = useState<UserSettingsRemote>({
    ...DEFAULT_REMOTE_SETTINGS,
  });

  const mergedSettings: UserSettings = useMemo(() => {
    return {
      ...userRemoteSettings,
      ...interfaceSettings,
    };
  }, [userRemoteSettings, interfaceSettings]);

  const refVars = useRef({ mergedSettings, userRemoteSettings, interfaceSettings, outCommand, setInterfaceSettings });
  refVars.current = { mergedSettings, userRemoteSettings, interfaceSettings, outCommand, setInterfaceSettings };

  const handleSettingChange = useCallback(async (prop: keyof UserSettings, value: boolean | string) => {
    const { userRemoteSettings, interfaceSettings, outCommand, setInterfaceSettings } = refVars.current;

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
  }, []);

  const renderSettingItem = useCallback(
    (item: SettingsListItem) => {
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

      return null;
    },
    [handleSettingChange],
  );

  return (
    <MapSettingsContext.Provider value={{ renderSettingItem, setUserRemoteSettings }}>
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
