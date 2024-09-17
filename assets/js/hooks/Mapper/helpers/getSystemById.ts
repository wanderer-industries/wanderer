import { SolarSystemRawType, SolarSystemStaticInfoRaw } from '@/hooks/Mapper/types';

export const getSystemById = (systems: SolarSystemRawType[], systemId: string) => systems.find(x => x.id === systemId);

export const getSystemStaticById = (systems: SolarSystemStaticInfoRaw[], systemId: string) =>
  systems.find(x => x.solar_system_id.toString() === systemId);
