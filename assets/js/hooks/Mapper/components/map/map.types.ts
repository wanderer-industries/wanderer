import { SolarSystemRawType } from '@/hooks/Mapper/types/system';
import { SolarSystemConnection } from '@/hooks/Mapper/types';

export type MapSolarSystemType = Omit<SolarSystemRawType, 'position'>;

export type OnMapSelectionChange = (event: {
  systems: string[];
  connections: Pick<SolarSystemConnection, 'source' | 'target'>[];
}) => void;
