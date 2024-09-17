export enum MassState {
  normal,
  half,
  verge,
}

export enum TimeStatus {
  default,
  eol,
}

// export enum ShipSizeStatus {
//   small, // frigates, destroyers - less than 5K t
//   medium, // less than 20K t
//   large, // less than 375K t
//   capital, // less than 1.8M t
// }

export enum ShipSizeStatus {
  small, // frigates, destroyers - less than 5K t
  normal,
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
};
