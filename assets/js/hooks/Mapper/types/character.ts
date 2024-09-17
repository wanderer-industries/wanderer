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

export type WithIsOwnCharacter = {
  isOwn: boolean;
};
