export enum ConnectionType {
  wormhole,
  gate,
  bridge,
}

export enum MassState {
  normal,
  half,
  verge,
}

export enum TimeStatus {
  reserved, // TODO: this reserved for not broke prev solution
  _1h,
  _4h,
  _4h30m,
  _16h,
  _24h,
  _48h,
}

export enum ShipSizeStatus {
  small = 0, // frigates, destroyers - less than 5K t
  medium = 1, // less than 62K t
  large = 2, // less than 375K t
  freight = 3, // less than 1M t
  capital = 4, // less than 1.8M t
}

export type SolarSystemConnection = {
  // expect that it will be string which joined solarSystemSource and solarSystemTarget
  id: string;

  time_status: TimeStatus;
  mass_status: MassState;
  ship_size_type: ShipSizeStatus;
  locked: boolean;

  source: string;
  target: string;

  type?: ConnectionType;
};
