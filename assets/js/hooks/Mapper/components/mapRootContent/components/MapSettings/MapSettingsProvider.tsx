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
import { InputText } from 'primereact/inputtext';
import { Slider } from 'primereact/slider';
import { Button } from 'primereact/button';
import { Dialog } from 'primereact/dialog';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { WithChildren } from '@/hooks/Mapper/types/common.ts';

type MapSettingsContextType = {
  renderSettingItem: (item: SettingsListItem) => ReactNode;
  updateSetting: (prop: keyof UserSettings, value: boolean | string | Record<string, string>) => Promise<void>;
  setUserRemoteSettings: Dispatch<SetStateAction<UserSettingsRemote>>;
  settings: UserSettings;
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

  const handleSettingChange = useCallback(
    async (prop: keyof UserSettings, value: boolean | string | Record<string, string>) => {
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
    },
    [],
  );

  const renderSettingItem = useCallback(
    (item: SettingsListItem) => {
      let isDisabled = false;
      if (item.dependsOn) {
        const dependsOnValue = refVars.current.mergedSettings[item.dependsOn];
        if (!dependsOnValue) {
          isDisabled = true;
        }
      }

      const currentValue = refVars.current.mergedSettings[item.prop];
      
      const containerClass = `grid grid-cols-[auto_1fr_auto] items-center ${isDisabled ? 'opacity-50 pointer-events-none' : ''}`;

      if (item.type === 'checkbox') {
        return (
          <div key={item.prop.toString()} className={isDisabled ? 'opacity-50 pointer-events-none' : ''}>
            <PrettySwitchbox
              label={item.label}
              checked={!!currentValue}
              setChecked={checked => handleSettingChange(item.prop, checked)}
            />
          </div>
        );
      }

      if (item.type === 'dropdown' && item.options) {
        return (
          <div key={item.prop.toString()} className={containerClass}>
            <label className="text-[var(--gray-200)] text-[13px] select-none">{item.label}:</label>
            <div className="border-b-2 border-dotted border-[#3f3f3f] h-px mx-3" />
            <Dropdown
              className="text-sm"
              value={currentValue}
              options={item.options}
              onChange={e => handleSettingChange(item.prop, e.value)}
              placeholder="Select an option"
              disabled={isDisabled}
            />
          </div>
        );
      }

      if (item.type === 'slider') {
        return (
          <div key={item.prop.toString()} className={`grid grid-cols-[auto_1fr_auto] items-center gap-4 my-2 ${isDisabled ? 'opacity-50 pointer-events-none' : ''}`}>
            <label className="text-[var(--gray-200)] text-[13px] select-none">{item.label}:</label>
            <Slider
              value={(currentValue as number) || 0}
              onChange={e => handleSettingChange(item.prop, e.value as number)}
              className="w-full"
              disabled={isDisabled}
            />
            <span className="text-[var(--gray-200)] text-[13px] w-8 text-right">
              {currentValue}%
            </span>
          </div>
        );
      }

      if (item.type === 'text') {
        return (
          <div key={item.prop.toString()} className={`flex flex-col gap-1 w-full mt-2 mb-2 ${isDisabled ? 'opacity-50 pointer-events-none' : ''}`}>
            {item.label && <label className="text-[var(--gray-200)] text-[13px] select-none">{item.label}</label>}
            <InputText
              className="text-sm w-full"
              defaultValue={(currentValue as string) || ''}
              onBlur={e => handleSettingChange(item.prop, e.target.value)}
              placeholder={item.placeholder}
              disabled={isDisabled}
            />
            {item.helperText && <small className="text-gray-400 text-xs mt-1">{item.helperText}</small>}
          </div>
        );
      }

      if (item.type === 'sound_selector') {
        return (
          <SoundSelectorItem
            key={item.prop.toString()}
            item={item}
            currentValue={currentValue as string}
            isDisabled={isDisabled}
            handleSettingChange={handleSettingChange}
            outCommand={refVars.current.outCommand}
          />
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

interface SoundSelectorItemProps {
  item: SettingsListItem;
  currentValue: string;
  isDisabled: boolean;
  handleSettingChange: (prop: keyof UserSettings, value: string) => void;
  outCommand: any;
}

const SoundSelectorItem = ({ item, currentValue, isDisabled, handleSettingChange, outCommand }: SoundSelectorItemProps) => {
  const [visible, setVisible] = useState(false);
  const [sounds, setSounds] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);
  const audioRef = useRef<HTMLAudioElement>(null);

  const openDialog = async () => {
    setVisible(true);
    setLoading(true);
    try {
      const res = await outCommand({ type: OutCommand.getAvailableSounds, data: null });
      setSounds(res?.sounds || []);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  const playSound = (sound: string) => {
    if (audioRef.current) {
      audioRef.current.src = `/sounds/${sound}`;
      audioRef.current.play().catch(console.error);
    }
  };

  const selectSound = (sound: string) => {
    handleSettingChange(item.prop, sound);
    setVisible(false);
  };

  return (
    <div className={`grid grid-cols-[auto_1fr_auto] items-center my-2 ${isDisabled ? 'opacity-50 pointer-events-none' : ''}`}>
      <label className="text-[var(--gray-200)] text-[13px] select-none">{item.label}:</label>
      <div className="border-b-2 border-dotted border-[#3f3f3f] h-px mx-3" />
      <Button 
        label={currentValue || 'Select Sound'} 
        onClick={openDialog} 
        disabled={isDisabled}
        size="small"
        outlined
      />
      <Dialog header="Select Notification Sound" visible={visible} onHide={() => setVisible(false)} className="w-[400px]">
        {loading ? (
          <div className="p-4 text-center text-sm text-gray-400">Loading sounds...</div>
        ) : (
          <div className="flex flex-col gap-2 max-h-[300px] overflow-y-auto custom-scrollbar pr-2">
            {sounds.length === 0 && <div className="text-gray-400 text-sm">No sounds found.</div>}
            {sounds.map(sound => (
              <div key={sound} className="flex justify-between items-center p-2 border-b border-stone-700/50 hover:bg-stone-800 transition-colors rounded">
                <span className="text-sm font-mono text-gray-200">{sound}</span>
                <div className="flex gap-2">
                  <Button icon="pi pi-play" rounded text severity="info" aria-label="Play" onClick={() => playSound(sound)} />
                  <Button label="Select" size="small" outlined onClick={() => selectSound(sound)} />
                </div>
              </div>
            ))}
          </div>
        )}
      </Dialog>
      <audio ref={audioRef} />
    </div>
  );
};

export const useMapSettings = () => {
  const context = useContext(MapSettingsContext);
  if (!context) {
    throw new Error('useMapSettings must be used within a MapSettingsProvider');
  }
  return context;
};
