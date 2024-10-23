import { ContextStoreDataUpdate, useContextStore } from '@/hooks/Mapper/utils';
import { createContext, Dispatch, ForwardedRef, forwardRef, RefObject, SetStateAction, useContext } from 'react';
import { MapHandlers, MapUnionTypes, OutCommandHandler, SolarSystemConnection } from '@/hooks/Mapper/types';
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
};

export enum InterfaceStoredSettingsProps {
  isShowMenu = 'isShowMenu',
  isShowMinimap = 'isShowMinimap',
  isShowKSpace = 'isShowKSpace',
}

export type InterfaceStoredSettings = {
  isShowMenu: boolean;
  isShowMinimap: boolean;
  isShowKSpace: boolean;
};

export const STORED_INTERFACE_DEFAULT_VALUES: InterfaceStoredSettings = {
  isShowMenu: false,
  isShowMinimap: true,
  isShowKSpace: false,
};

export interface MapRootContextProps {
  update: ContextStoreDataUpdate<MapRootData>;
  data: MapRootData;
  mapRef: RefObject<MapHandlers>;
  outCommand: OutCommandHandler;
  interfaceSettings: InterfaceStoredSettings;
  setInterfaceSettings: Dispatch<SetStateAction<InterfaceStoredSettings>>;
}

const MapRootContext = createContext<MapRootContextProps>({
  update: () => {},
  data: { ...INITIAL_DATA },
  mapRef: { current: null },
  // @ts-ignore
  outCommand: async () => void 0,
  interfaceSettings: STORED_INTERFACE_DEFAULT_VALUES,
  setInterfaceSettings: () => null,
});

type MapRootProviderProps = {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  fwdRef: ForwardedRef<any>;
  mapRef: RefObject<MapHandlers>;
  outCommand: OutCommandHandler;
} & WithChildren;

// eslint-disable-next-line react/display-name
const MapRootHandlers = forwardRef(({ children }: WithChildren, fwdRef: ForwardedRef<any>) => {
  useMapRootHandlers(fwdRef);
  return <>{children}</>;
});

// eslint-disable-next-line react/display-name
export const MapRootProvider = ({ children, fwdRef, mapRef, outCommand }: MapRootProviderProps) => {
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
        mapRef: mapRef,
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
