import React, { createContext, useContext } from 'react';
import { OutCommandHandler } from '@/hooks/Mapper/types/mapHandlers.ts';
import { MapUnionTypes, SystemSignature } from '@/hooks/Mapper/types';
import { ContextStoreDataUpdate, useContextStore } from '@/hooks/Mapper/utils';

export type MapData = MapUnionTypes & {
  isConnecting: boolean;
  hoverNodeId: string | null;
  visibleNodes: Set<string>;
  showKSpaceBG: boolean;
  isThickConnections: boolean;
  linkedSigEveId: string;
  localShowShipName: boolean;
  systemHighlighted: string | undefined;
};

interface MapProviderProps {
  children: React.ReactNode;
  onCommand: OutCommandHandler;
}

const INITIAL_DATA: MapData = {
  wormholesData: {},
  wormholes: [],
  effects: {},
  characters: [],
  userCharacters: [],
  presentCharacters: [],
  systems: [],
  hubs: [],
  kills: {},
  isConnecting: false,
  connections: [],
  hoverNodeId: null,
  linkedSigEveId: '',
  visibleNodes: new Set(),
  showKSpaceBG: false,
  isThickConnections: false,
  userPermissions: {},
  systemSignatures: {} as Record<string, SystemSignature[]>,
  options: {} as Record<string, string | boolean>,
  isSubscriptionActive: false,
  mainCharacterEveId: null,
  followingCharacterEveId: null,
  userHubs: [],
  pings: [],
  localShowShipName: false,
  systemHighlighted: undefined,
};

export interface MapContextProps {
  update: ContextStoreDataUpdate<MapData>;
  data: MapData;
  outCommand: OutCommandHandler;
}

const MapContext = createContext<MapContextProps>({
  update: () => {},
  data: { ...INITIAL_DATA },
  // @ts-ignore
  outCommand: async () => void 0,
});

export const MapProvider = ({ children, onCommand }: MapProviderProps) => {
  const { update, ref } = useContextStore<MapData>({ ...INITIAL_DATA });

  return (
    <MapContext.Provider
      value={{
        update,
        data: ref,
        outCommand: onCommand,
      }}
    >
      {children}
    </MapContext.Provider>
  );
};

export const useMapState = () => {
  const context = useContext<MapContextProps>(MapContext);
  return context;
};
