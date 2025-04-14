import { SolarSystemStaticInfoRaw } from '@/hooks/Mapper/types';

export enum SignatureGroup {
  CosmicSignature = 'Cosmic Signature',
  Wormhole = 'Wormhole',
  GasSite = 'Gas Site',
  RelicSite = 'Relic Site',
  DataSite = 'Data Site',
  OreSite = 'Ore Site',
  CombatSite = 'Combat Site',
}

export enum SignatureKind {
  CosmicSignature = 'Cosmic Signature',
  CosmicAnomaly = 'Cosmic Anomaly',
  Structure = 'Structure',
  Ship = 'Ship',
  Deployable = 'Deployable',
  Drone = 'Drone',
  Starbase = 'Starbase',
}

export type GroupType = {
  id: string;
  icon: string;
  w: number;
  h: number;
};

export type SignatureCustomInfo = {
  k162Type?: string;
  isEOL?: boolean;
};

export type SystemSignature = {
  eve_id: string;
  character_eve_id?: string;
  character_name?: string;
  kind: SignatureKind;
  name: string;
  // SignatureCustomInfo
  custom_info?: string;
  description?: string;
  group: SignatureGroup;
  type: string;
  linked_system?: SolarSystemStaticInfoRaw;
  inserted_at?: string;
  updated_at?: string;
  temp_name?: string;
};

export interface ExtendedSystemSignature extends SystemSignature {
  pendingDeletion?: boolean;
  pendingAddition?: boolean;
  pendingUntil?: number;
  finalTimeoutId?: number;
}

export enum SignatureKindENG {
  CosmicSignature = 'Cosmic Signature',
  CosmicAnomaly = 'Cosmic Anomaly',
  Structure = 'Structure',
  Ship = 'Ship',
  Deployable = 'Deployable',
  Drone = 'Drone',
  Starbase = 'Starbase',
}

export enum SignatureKindRU {
  CosmicSignature = 'Скрытый сигнал',
  CosmicAnomaly = 'Космическая аномалия',
  Structure = 'Сооружение',
  Ship = 'Корабль',
  Deployable = 'Полевые блоки',
  Drone = 'Дрон',
  Starbase = 'Starbase',
}

export enum SignatureGroupENG {
  CosmicSignature = 'Cosmic Signature',
  Wormhole = 'Wormhole',
  GasSite = 'Gas Site',
  RelicSite = 'Relic Site',
  DataSite = 'Data Site',
  OreSite = 'Ore Site',
  CombatSite = 'Combat Site',
}

export enum SignatureGroupRU {
  CosmicSignature = 'Скрытый сигнал',
  Wormhole = 'Червоточина',
  GasSite = 'Газовый район',
  RelicSite = 'Археологический район',
  DataSite = 'Информационный район',
  OreSite = 'Астероидный район',
  CombatSite = 'Боевой район',
}
