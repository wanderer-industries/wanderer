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
  time_status?: number;
  isCrit?: boolean;
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
  deleted?: boolean;
  temporary_name?: string;
};

export interface ExtendedSystemSignature extends SystemSignature {
  pendingDeletion?: boolean;
  pendingAddition?: boolean;
  pendingUntil?: number;
  finalTimeoutId?: number;
  deleted?: boolean;
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

export enum SignatureKindFR {
  CosmicSignature = 'Signature cosmique (type)',
  CosmicAnomaly = 'Anomalie cosmique',
  Structure = 'Structure',
  Ship = 'Vaisseau',
  Deployable = 'Déployable',
  Drone = 'Drone',
  Starbase = 'Base stellaire',
}

export enum SignatureKindDE {
  CosmicSignature = 'Kosmische Signatur (typ)',
  CosmicAnomaly = 'Kosmische Anomalie',
  Structure = 'Struktur',
  Ship = 'Schiff',
  Deployable = 'Mobile Struktur',
  Drone = 'Drohne',
  Starbase = 'Sternenbasis',
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

export enum SignatureGroupFR {
  CosmicSignature = 'Signature cosmique (groupe)',
  Wormhole = 'Trou de ver',
  GasSite = 'Site de collecte de gaz',
  RelicSite = 'Site de reliques',
  DataSite = 'Site de données',
  OreSite = 'Site de minerai',
  CombatSite = 'Site de combat',
}

export enum SignatureGroupDE {
  CosmicSignature = 'Kosmische Signatur (gruppe)',
  Wormhole = 'Wurmloch',
  GasSite = 'Gasgebiet',
  RelicSite = 'Reliktgebiet',
  DataSite = 'Datengebiet',
  OreSite = 'Mineraliengebiet',
  CombatSite = 'Kampfgebiet',
}
