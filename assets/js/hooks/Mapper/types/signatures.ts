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

export type GroupType = {
  id: string;
  icon: string;
  w: number;
  h: number;
};

export type SystemSignature = {
  eve_id: string;
  kind: string;
  name: string;
  custom_info?: string;
  description?: string;
  group: SignatureGroup;
  type: string;
  k162Type?: string;
  linked_system?: SolarSystemStaticInfoRaw;
  inserted_at?: string;
  updated_at?: string;
};
