import { SolarSystemRawType } from '@/hooks/Mapper/types/system';
import { SolarSystemConnection } from '@/hooks/Mapper/types';
import { XYPosition } from 'reactflow';

export type MapSolarSystemType = Omit<SolarSystemRawType, 'position'>;

export type OnMapSelectionChange = (event: {
  systems: string[];
  connections: Pick<SolarSystemConnection, 'source' | 'target'>[];
}) => void;

export type OnMapAddSystemCallback = (props: { coordinates: XYPosition | null }) => void;

export type MapViewport = { zoom: 1; x: 0; y: 0 };
