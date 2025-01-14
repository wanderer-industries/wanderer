export type StructureStatus = 'Powered' | 'Anchoring' | 'Unanchoring' | 'Low Power' | 'Abandoned' | 'Reinforced';

export interface StructureItem {
  id: string;
  systemId?: string;
  structureTypeId?: string;
  structureType?: string;
  name: string;
  ownerName?: string;
  ownerId?: string;
  ownerTicker?: string;
  notes?: string;
  status: StructureStatus;
  endTime?: string;
}

export const STRUCTURE_TYPE_MAP: Record<string, string> = {
  '35825': 'Raitaru',
  '35826': 'Azbel',
  '35827': 'Sotiyo',
  '35832': 'Astrahus',
  '35833': 'Fortizar',
  '35834': 'Keepstar',
  '35835': 'Athanor',
  '35836': 'Tatara',
  '40340': 'Upwell Palatine Keepstar',
  '47512': "'Moreau' Fortizar",
  '47513': "'Draccous' Fortizar",
  '47514': "'Horizon' Fortizar",
  '47515': "'Marginis' Fortizar",
  '47516': "'Prometheus' Fortizar",
};
