import { ContextStoreDataUpdate, useContextStore } from '@/hooks/Mapper/utils';
import { createContext, Dispatch, ForwardedRef, forwardRef, SetStateAction, useContext } from 'react';
import {
  ActivitySummary,
  CommandLinkSignatureToSystem,
  MapUnionTypes,
  OutCommandHandler,
  SolarSystemConnection,
  TrackingCharacter,
  UseCharactersCacheData,
  UseCommentsData,
} from '@/hooks/Mapper/types';
import { useCharactersCache, useComments, useMapRootHandlers } from '@/hooks/Mapper/mapRootProvider/hooks';
import { WithChildren } from '@/hooks/Mapper/types/common.ts';
import {
  ToggleWidgetVisibility,
  useStoreWidgets,
  WindowStoreInfo,
} from '@/hooks/Mapper/mapRootProvider/hooks/useStoreWidgets.ts';
import { WindowsManagerOnChange } from '@/hooks/Mapper/components/ui-kit/WindowManager';
import { DetailedKill } from '../types/kills';
import {
  InterfaceStoredSettings,
  KillsWidgetSettings,
  LocalWidgetSettings,
  MapSettings,
  MapUserSettings,
  OnTheMapSettingsType,
  RoutesType,
} from '@/hooks/Mapper/mapRootProvider/types.ts';
import {
  DEFAULT_KILLS_WIDGET_SETTINGS,
  DEFAULT_MAP_SETTINGS,
  DEFAULT_ON_THE_MAP_SETTINGS,
  DEFAULT_ROUTES_SETTINGS,
  DEFAULT_WIDGET_LOCAL_SETTINGS,
  STORED_INTERFACE_DEFAULT_VALUES,
} from '@/hooks/Mapper/mapRootProvider/constants.ts';
import { useMapUserSettings } from '@/hooks/Mapper/mapRootProvider/hooks/useMapUserSettings.ts';
import { useGlobalHooks } from '@/hooks/Mapper/mapRootProvider/hooks/useGlobalHooks.ts';
import { DEFAULT_SIGNATURE_SETTINGS, SignatureSettingsType } from '@/hooks/Mapper/constants/signatures';

export type MapRootData = MapUnionTypes & {
  selectedSystems: string[];
  selectedConnections: Pick<SolarSystemConnection, 'source' | 'target'>[];
  linkSignatureToSystem: CommandLinkSignatureToSystem | null;
  detailedKills: Record<string, DetailedKill[]>;
  showCharacterActivity: boolean;
  characterActivityData: {
    activity: ActivitySummary[];
    loading?: boolean;
  };
  trackingCharactersData: TrackingCharacter[];
  loadingPublicRoutes: boolean;
  map_slug: string | null;
};

const INITIAL_DATA: MapRootData = {
  wormholesData: {},
  wormholes: [],
  effects: {},
  characters: [],
  showCharacterActivity: false,
  characterActivityData: {
    activity: [],
    loading: false,
  },
  trackingCharactersData: [],
  userCharacters: [],
  presentCharacters: [],
  systems: [],
  systemSignatures: {},
  hubs: [],
  userHubs: [],
  routes: undefined,
  userRoutes: undefined,
  kills: [],
  connections: [],
  detailedKills: {},
  selectedSystems: [],
  selectedConnections: [],
  userPermissions: {},
  options: {},
  isSubscriptionActive: false,
  linkSignatureToSystem: null,
  mainCharacterEveId: null,
  followingCharacterEveId: null,
  pings: [],
  loadingPublicRoutes: false,
  map_slug: null,
};

export enum InterfaceStoredSettingsProps {
  isShowMenu = 'isShowMenu',
  isShowKSpace = 'isShowKSpace',
  isThickConnections = 'isThickConnections',
  isShowUnsplashedSignatures = 'isShowUnsplashedSignatures',
  isShowBackgroundPattern = 'isShowBackgroundPattern',
  isSoftBackground = 'isSoftBackground',
  theme = 'theme',
}

export interface MapRootContextProps {
  update: ContextStoreDataUpdate<MapRootData>;
  data: MapRootData;
  outCommand: OutCommandHandler;
  windowsSettings: WindowStoreInfo;
  toggleWidgetVisibility: ToggleWidgetVisibility;
  updateWidgetSettings: WindowsManagerOnChange;
  resetWidgets: () => void;
  comments: UseCommentsData;
  charactersCache: UseCharactersCacheData;

  /**
   * !!!
   * DO NOT PASS THIS PROP INTO COMPONENT
   * !!!
   * */
  storedSettings: {
    interfaceSettings: InterfaceStoredSettings;
    setInterfaceSettings: Dispatch<SetStateAction<InterfaceStoredSettings>>;
    settingsRoutes: RoutesType;
    settingsRoutesUpdate: Dispatch<SetStateAction<RoutesType>>;
    settingsLocal: LocalWidgetSettings;
    settingsLocalUpdate: Dispatch<SetStateAction<LocalWidgetSettings>>;
    settingsSignatures: SignatureSettingsType;
    settingsSignaturesUpdate: Dispatch<SetStateAction<SignatureSettingsType>>;
    settingsOnTheMap: OnTheMapSettingsType;
    settingsOnTheMapUpdate: Dispatch<SetStateAction<OnTheMapSettingsType>>;
    settingsKills: KillsWidgetSettings;
    settingsKillsUpdate: Dispatch<SetStateAction<KillsWidgetSettings>>;
    mapSettings: MapSettings;
    mapSettingsUpdate: Dispatch<SetStateAction<MapSettings>>;
    isReady: boolean;
    hasOldSettings: boolean;
    getSettingsForExport(): string | undefined;
    applySettings(settings: MapUserSettings): boolean;
    resetSettings(settings: MapUserSettings): void;
    checkOldSettings(): void;
  };
}

const MapRootContext = createContext<MapRootContextProps>({
  update: () => {},
  data: { ...INITIAL_DATA },
  // @ts-ignore
  outCommand: async () => void 0,
  comments: {
    loadComments: async () => {},
    comments: new Map(),
    lastUpdateKey: 0,
    addComment: function (): void {
      throw new Error('Function not implemented.');
    },
    removeComment: function (): void {
      throw new Error('Function not implemented.');
    },
  },
  charactersCache: {
    loadCharacter: function (): Promise<void> {
      throw new Error('Function not implemented.');
    },
    characters: new Map(),
    lastUpdateKey: 0,
  },
  storedSettings: {
    interfaceSettings: STORED_INTERFACE_DEFAULT_VALUES,
    setInterfaceSettings: () => null,
    settingsRoutes: DEFAULT_ROUTES_SETTINGS,
    settingsRoutesUpdate: () => null,
    settingsLocal: DEFAULT_WIDGET_LOCAL_SETTINGS,
    settingsLocalUpdate: () => null,
    settingsSignatures: DEFAULT_SIGNATURE_SETTINGS,
    settingsSignaturesUpdate: () => null,
    settingsOnTheMap: DEFAULT_ON_THE_MAP_SETTINGS,
    settingsOnTheMapUpdate: () => null,
    settingsKills: DEFAULT_KILLS_WIDGET_SETTINGS,
    settingsKillsUpdate: () => null,
    mapSettings: DEFAULT_MAP_SETTINGS,
    mapSettingsUpdate: () => null,
    isReady: false,
    hasOldSettings: false,
    getSettingsForExport: () => '',
    applySettings: () => false,
    resetSettings: () => null,
    checkOldSettings: () => null,
  },
});

type MapRootProviderProps = {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  fwdRef: ForwardedRef<any>;
  outCommand: OutCommandHandler;
} & WithChildren;

// eslint-disable-next-line react/display-name
const MapRootHandlers = forwardRef(({ children }: WithChildren, fwdRef: ForwardedRef<any>) => {
  useMapRootHandlers(fwdRef);
  useGlobalHooks();
  return <>{children}</>;
});

// eslint-disable-next-line react/display-name
export const MapRootProvider = ({ children, fwdRef, outCommand }: MapRootProviderProps) => {
  const { update, ref } = useContextStore<MapRootData>({ ...INITIAL_DATA });

  const storedSettings = useMapUserSettings(ref, outCommand);

  const { windowsSettings, toggleWidgetVisibility, updateWidgetSettings, resetWidgets } =
    useStoreWidgets(storedSettings);

  const comments = useComments({ outCommand });
  const charactersCache = useCharactersCache({ outCommand });

  return (
    <MapRootContext.Provider
      value={{
        update,
        data: ref,
        outCommand,
        windowsSettings,
        updateWidgetSettings,
        toggleWidgetVisibility,
        resetWidgets,
        comments,
        charactersCache,
        storedSettings,
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
