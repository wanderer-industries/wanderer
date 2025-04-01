export type ShipTypeInfoRaw = {
  capacity: string;
  group_id: number;
  group_name: string;
  mass: string;
  name: string;
  type_id: number;
  volume: string;
};

export type ShipTypeRaw = {
  ship_name: string;
  ship_type_id: number;
  ship_type_info: ShipTypeInfoRaw;
};

export type LocationRaw = {
  solar_system_id: number | null;
  structure_id: number | null;
  station_id: number | null;
};

export type CharacterTypeRaw = {
  eve_id: string;
  location: LocationRaw | null;
  name: string;
  online: boolean;
  ship: ShipTypeRaw | null;

  alliance_id: number | null;
  alliance_name: number | null;
  alliance_ticker: number | null;
  corporation_id: number;
  corporation_name: string;
  corporation_ticker: string;
};

export interface TrackingCharacter {
  character: CharacterTypeRaw;
  tracked: boolean;
  followed: boolean;
}

export type WithIsOwnCharacter = {
  isOwn: boolean;
};

export interface EveCharacterType {
  alliance_ticker: string;
  corporation_ticker: string;
  eve_id: string;
  name: string;
}

export interface CharacterCache {
  loading: boolean;
  loaded: boolean;
  data: EveCharacterType | null;
}

export interface UseCharactersCacheData {
  loadCharacter: (systemId: string) => Promise<void>;
  characters: Map<string, CharacterCache>;
  lastUpdateKey: number;
}
