import { ContextStoreDataUpdate, useContextStore } from '@/hooks/Mapper/utils';
import { createContext, Dispatch, ForwardedRef, forwardRef, SetStateAction, useContext, useEffect } from 'react';
import {
  CommandLinkSignatureToSystem,
  MapHandlers,
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
import { ActivitySummary } from '../components/mapRootContent/components/CharacterActivity/CharacterActivity';
import { TrackingCharacter } from '../components/mapRootContent/components/TrackAndFollow/types';

export type MapRootData = MapUnionTypes & {
  selectedSystems: string[];
  selectedConnections: Pick<SolarSystemConnection, 'source' | 'target'>[];
  linkSignatureToSystem: CommandLinkSignatureToSystem | null;
  detailedKills: Record<string, DetailedKill[]>;
  showCharacterActivity: boolean;
  characterActivityData: ActivitySummary[];
  showTrackAndFollow: boolean;
  trackingCharactersData: TrackingCharacter[];
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
  showCharacterActivity: false,
  characterActivityData: [],
  showTrackAndFollow: false,
  trackingCharactersData: [],
};

export enum AvailableThemes {
  default = 'default',
  pathfinder = 'pathfinder',
}

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
  theme: AvailableThemes;
};

export const STORED_INTERFACE_DEFAULT_VALUES: InterfaceStoredSettings = {
  isShowMenu: false,
  isShowMinimap: true,
  isShowKSpace: false,
  isThickConnections: false,
  isShowUnsplashedSignatures: false,
  isShowBackgroundPattern: true,
  isSoftBackground: false,
  theme: AvailableThemes.default,
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
  fwdRef: ForwardedRef<MapHandlers>;
  outCommand: OutCommandHandler;
} & WithChildren;

const MapRootHandlers = forwardRef<MapHandlers, WithChildren>(({ children }, fwdRef) => {
  useMapRootHandlers(fwdRef);
  return <>{children}</>;
});

MapRootHandlers.displayName = 'MapRootHandlers';

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
