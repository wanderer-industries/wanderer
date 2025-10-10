import { XYPosition } from 'reactflow';

import { SystemSignature } from './signatures';

export enum SolarSystemStaticInfoRawNames {
  regionId = 'region_id',
  constellationId = 'constellation_id',
  solarSystemId = 'solar_system_id',
  solarSystemName = 'solar_system_name',
  solarSystemNameLc = 'solar_system_name_lc',
  constellationName = 'constellation_name',
  regionName = 'region_name',
  systemClass = 'system_class',
  security = 'security',
  typeDescription = 'type_description',
  classTitle = 'class_title',
  isShattered = 'is_shattered',
  effectName = 'effect_name',
  effectPower = 'effect_power',
  statics = 'statics',
  wandering = 'wandering',
  triglavianInvasionStatus = 'triglavian_invasion_status',
  sunTypeId = 'sun_type_id',
}

export enum SolarSystemStaticInfoNames {
  regionId = 'regionId',
  constellationId = 'constellationId',
  solarSystemId = 'solarSystemId',
  solarSystemName = 'solarSystemName',
  solarSystemNameLc = 'solarSystemNameLc',
  constellationName = 'constellationName',
  regionName = 'regionName',
  systemClass = 'systemClass',
  security = 'security',
  typeDescription = 'typeDescription',
  classTitle = 'classTitle',
  isShattered = 'isShattered',
  effectName = 'effectName',
  effectPower = 'effectPower',
  statics = 'statics',
  wandering = 'wandering',
  triglavianInvasionStatus = 'triglavianInvasionStatus',
  sunTypeId = 'sunTypeId',
}

export const SYSTEM_STATIC_INFO_MAP = {
  [SolarSystemStaticInfoRawNames.regionId]: SolarSystemStaticInfoNames.regionId,
  [SolarSystemStaticInfoRawNames.constellationId]: SolarSystemStaticInfoNames.constellationId,
  [SolarSystemStaticInfoRawNames.solarSystemId]: SolarSystemStaticInfoNames.solarSystemId,
  [SolarSystemStaticInfoRawNames.solarSystemName]: SolarSystemStaticInfoNames.solarSystemName,
  [SolarSystemStaticInfoRawNames.solarSystemNameLc]: SolarSystemStaticInfoNames.solarSystemNameLc,
  [SolarSystemStaticInfoRawNames.constellationName]: SolarSystemStaticInfoNames.constellationName,
  [SolarSystemStaticInfoRawNames.regionName]: SolarSystemStaticInfoNames.regionName,
  [SolarSystemStaticInfoRawNames.systemClass]: SolarSystemStaticInfoNames.systemClass,
  [SolarSystemStaticInfoRawNames.security]: SolarSystemStaticInfoNames.security,
  [SolarSystemStaticInfoRawNames.typeDescription]: SolarSystemStaticInfoNames.typeDescription,
  [SolarSystemStaticInfoRawNames.classTitle]: SolarSystemStaticInfoNames.classTitle,
  [SolarSystemStaticInfoRawNames.isShattered]: SolarSystemStaticInfoNames.isShattered,
  [SolarSystemStaticInfoRawNames.effectName]: SolarSystemStaticInfoNames.effectName,
  [SolarSystemStaticInfoRawNames.effectPower]: SolarSystemStaticInfoNames.effectPower,
  [SolarSystemStaticInfoRawNames.statics]: SolarSystemStaticInfoNames.statics,
  [SolarSystemStaticInfoRawNames.wandering]: SolarSystemStaticInfoNames.wandering,
  [SolarSystemStaticInfoRawNames.triglavianInvasionStatus]: SolarSystemStaticInfoNames.triglavianInvasionStatus,
  [SolarSystemStaticInfoRawNames.sunTypeId]: SolarSystemStaticInfoNames.sunTypeId,
};

export type SolarSystemStaticInfoRaw = {
  region_id: number;
  constellation_id: number;
  solar_system_id: number;
  solar_system_name: string;
  solar_system_name_lc: string;
  constellation_name: string;
  region_name: string;
  system_class: number;
  security: string;
  type_description: string;
  class_title: string;
  is_shattered: boolean;
  effect_name: string;
  effect_power: number;
  statics: string[];
  wandering: string[];
  triglavian_invasion_status: string;
  sun_type_id: number;
};

export type SolarSystemStaticInfo = {
  regionId: number;
  constellationId: number;
  solarSystemId: number;
  solarSystemName: string;
  solarSystemNameLc: string;
  constellationName: string;
  regionName: string;
  systemClass: number;
  security: string;
  typeDescription: string;
  classTitle: string;
  isShattered: boolean;
  effectName: string;
  effectPower: number;
  statics: string[];
  wandering: string[];
  triglavianInvasionStatus: string;
  sunTypeId: number;
};

export type SolarSystemRawType = {
  id: string;
  position: XYPosition;
  description: string | null;
  labels: string | null;
  locked: boolean;
  tag: string | null;
  status: number;
  name: string | null;
  temporary_name: string | null;
  linked_sig_eve_id: string | null;
  comments_count: number | null;

  system_static_info: SolarSystemStaticInfoRaw;
  system_signatures: SystemSignature[];
};

export type SearchSystemItem = {
  class_title: string;
  constellation_name: string;
  label: string;
  region_name: string;
  system_static_info: SolarSystemStaticInfoRaw;
  value: number;
};
