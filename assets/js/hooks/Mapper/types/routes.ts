import { SolarSystemStaticInfoRaw } from '@/hooks/Mapper/types/system.ts';

export type SystemStaticInfoShort = Pick<
  SolarSystemStaticInfoRaw,
  | 'class_title'
  | 'security'
  | 'solar_system_id'
  | 'solar_system_name'
  | 'system_class'
  | 'triglavian_invasion_status'
  | 'region_name'
>;

type MappedSystem = SolarSystemStaticInfoRaw | undefined;

export type Route = {
  destination: number;
  has_connection: boolean;
  origin: number;
  systems?: number[];
  mapped_systems?: MappedSystem[];
  success?: boolean;
};

export type RoutesList = {
  loading: boolean;
  solar_system_id: string;
  routes: Route[];
  systems_static_data: SolarSystemStaticInfoRaw[];
};
