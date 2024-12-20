import { ContextStoreDataUpdate, useContextStore } from '@/hooks/Mapper/utils';
import { createContext, Dispatch, ForwardedRef, forwardRef, SetStateAction, useContext } from 'react';
import { MapUnionTypes, OutCommandHandler, SolarSystemConnection } from '@/hooks/Mapper/types';
import { useMapRootHandlers } from '@/hooks/Mapper/mapRootProvider/hooks';
import { WithChildren } from '@/hooks/Mapper/types/common.ts';
import useLocalStorageState from 'use-local-storage-state';

export type MapRootData = MapUnionTypes & {
  selectedSystems: string[];
  selectedConnections: Pick<SolarSystemConnection, 'source' | 'target'>[];
};

const INITIAL_DATA: MapRootData = {
  wormholesData: {},
  wormholes: [],
  effects: {},
  characters: [],
  userCharacters: [],
  presentCharacters: [],
  systems: [],
  hubs: [],
  routes: undefined,
  kills: [],
  connections: [],

  selectedSystems: [],
  selectedConnections: [],
  userPermissions: {},
  options: {},
};

export enum InterfaceStoredSettingsProps {
  isShowMenu = 'isShowMenu',
  isShowMinimap = 'isShowMinimap',
  isStickMinimapToLeft = 'isStickMinimapToLeft',
  isShowKSpace = 'isShowKSpace',
  isThickConnections = 'isThickConnections',
  isShowUnsplashedSignatures = 'isShowUnsplashedSignatures',
  isShowBackgroundPattern = 'isShowBackgroundPattern',
  isSoftBackground = 'isSoftBackground',
}

export type InterfaceStoredSettings = {
  isShowMenu: boolean;
  isShowMinimap: boolean;
  isStickMinimapToLeft: boolean;
  isShowKSpace: boolean;
  isThickConnections: boolean;
  isShowUnsplashedSignatures: boolean;
  isShowBackgroundPattern: boolean;
  isSoftBackground: boolean;
};

export const STORED_INTERFACE_DEFAULT_VALUES: InterfaceStoredSettings = {
  isShowMenu: false,
  isShowMinimap: true,
  isStickMinimapToLeft: false,
  isShowKSpace: false,
  isThickConnections: false,
  isShowUnsplashedSignatures: false,
  isShowBackgroundPattern: true,
  isSoftBackground: false,
};

export interface MapRootContextProps {
  update: ContextStoreDataUpdate<MapRootData>;
  data: MapRootData;
  outCommand: OutCommandHandler;
  interfaceSettings: InterfaceStoredSettings;
  setInterfaceSettings: Dispatch<SetStateAction<InterfaceStoredSettings>>;
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

  return (
    <MapRootContext.Provider
      value={{
        update,
        data: ref,
        outCommand: outCommand,
        setInterfaceSettings,
        interfaceSettings,
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
