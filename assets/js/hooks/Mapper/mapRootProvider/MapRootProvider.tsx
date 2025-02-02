import { ContextStoreDataUpdate, useContextStore } from '@/hooks/Mapper/utils';
import { createContext, Dispatch, ForwardedRef, forwardRef, SetStateAction, useContext, useEffect } from 'react';
import {
  CommandLinkSignatureToSystem,
  MapUnionTypes,
  OutCommandHandler,
  SolarSystemConnection,
} from '@/hooks/Mapper/types';
import { useMapRootHandlers } from '@/hooks/Mapper/mapRootProvider/hooks';
import { WithChildren } from '@/hooks/Mapper/types/common.ts';
import useLocalStorageState from 'use-local-storage-state';
import {
  ToggleWidgetVisibility,
  useStoreWidgets,
  WindowStoreInfo,
} from '@/hooks/Mapper/mapRootProvider/hooks/useStoreWidgets.ts';
import { WindowsManagerOnChange } from '@/hooks/Mapper/components/ui-kit/WindowManager';
import { DetailedKill } from '../types/kills';

export type MapRootData = MapUnionTypes & {
  selectedSystems: string[];
  selectedConnections: Pick<SolarSystemConnection, 'source' | 'target'>[];
  linkSignatureToSystem: CommandLinkSignatureToSystem | null;
  detailedKills: Record<string, DetailedKill[]>;
};

const INITIAL_DATA: MapRootData = {
  wormholesData: {},
  wormholes: [],
  effects: {},
  characters: [],
  userCharacters: [],
  presentCharacters: [],
  systems: [],
  systemSignatures: {},
  hubs: [],
  routes: undefined,
  kills: [],
  connections: [],
  detailedKills: {},
  selectedSystems: [],
  selectedConnections: [],
  userPermissions: {},
  options: {},
  isSubscriptionActive: false,
  linkSignatureToSystem: null,
};

export enum InterfaceStoredSettingsProps {
  isShowMenu = 'isShowMenu',
  isShowMinimap = 'isShowMinimap',
  isShowKSpace = 'isShowKSpace',
  isThickConnections = 'isThickConnections',
  isShowUnsplashedSignatures = 'isShowUnsplashedSignatures',
  isShowBackgroundPattern = 'isShowBackgroundPattern',
  isSoftBackground = 'isSoftBackground',
  theme = 'theme',
}

export type InterfaceStoredSettings = {
  isShowMenu: boolean;
  isShowMinimap: boolean;
  isShowKSpace: boolean;
  isThickConnections: boolean;
  isShowUnsplashedSignatures: boolean;
  isShowBackgroundPattern: boolean;
  isSoftBackground: boolean;
  theme: string;
};

export const STORED_INTERFACE_DEFAULT_VALUES: InterfaceStoredSettings = {
  isShowMenu: false,
  isShowMinimap: true,
  isShowKSpace: false,
  isThickConnections: false,
  isShowUnsplashedSignatures: false,
  isShowBackgroundPattern: true,
  isSoftBackground: false,
  theme: 'default',
};

export interface MapRootContextProps {
  update: ContextStoreDataUpdate<MapRootData>;
  data: MapRootData;
  outCommand: OutCommandHandler;
  interfaceSettings: InterfaceStoredSettings;
  setInterfaceSettings: Dispatch<SetStateAction<InterfaceStoredSettings>>;
  windowsSettings: WindowStoreInfo;
  toggleWidgetVisibility: ToggleWidgetVisibility;
  updateWidgetSettings: WindowsManagerOnChange;
  resetWidgets: () => void;
}

const MapRootContext = createContext<MapRootContextProps>({
  update: () => {},
  data: { ...INITIAL_DATA },
  // @ts-ignore
  outCommand: async () => void 0,
  interfaceSettings: STORED_INTERFACE_DEFAULT_VALUES,
  setInterfaceSettings: () => null,
});

type MapRootProviderProps = {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  fwdRef: ForwardedRef<any>;
  outCommand: OutCommandHandler;
} & WithChildren;

// eslint-disable-next-line react/display-name
const MapRootHandlers = forwardRef(({ children }: WithChildren, fwdRef: ForwardedRef<any>) => {
  useMapRootHandlers(fwdRef);
  return <>{children}</>;
});

// eslint-disable-next-line react/display-name
export const MapRootProvider = ({ children, fwdRef, outCommand }: MapRootProviderProps) => {
  const { update, ref } = useContextStore<MapRootData>({ ...INITIAL_DATA });

  const [interfaceSettings, setInterfaceSettings] = useLocalStorageState<InterfaceStoredSettings>(
    'window:interface:settings',
    {
      defaultValue: STORED_INTERFACE_DEFAULT_VALUES,
    },
  );
  const { windowsSettings, toggleWidgetVisibility, updateWidgetSettings, resetWidgets } = useStoreWidgets();

  useEffect(() => {
    let foundNew = false;
    const newVals = Object.keys(STORED_INTERFACE_DEFAULT_VALUES).reduce((acc, x) => {
      if (Object.keys(acc).includes(x)) {
        return acc;
      }

      foundNew = true;

      // @ts-ignore
      return { ...acc, [x]: STORED_INTERFACE_DEFAULT_VALUES[x] };
    }, interfaceSettings);

    if (foundNew) {
      setInterfaceSettings(newVals);
    }
  }, []);

  return (
    <MapRootContext.Provider
      value={{
        update,
        data: ref,
        outCommand: outCommand,
        setInterfaceSettings,
        interfaceSettings,
        windowsSettings,
        updateWidgetSettings,
        toggleWidgetVisibility,
        resetWidgets,
      }}
    >
      <MapRootHandlers ref={fwdRef}>{children}</MapRootHandlers>
    </MapRootContext.Provider>
  );
};

export const useMapRootState = () => {
  const context = useContext<MapRootContextProps>(MapRootContext);
  return context;
};
