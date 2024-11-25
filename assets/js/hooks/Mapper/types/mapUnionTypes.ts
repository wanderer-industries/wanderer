import { WormholeDataRaw } from '@/hooks/Mapper/types/wormholes.ts';
import { EffectRaw } from '@/hooks/Mapper/types/effect.ts';
import { CharacterTypeRaw } from '@/hooks/Mapper/types/character.ts';
import { SolarSystemRawType } from '@/hooks/Mapper/types/system.ts';
import { RoutesList } from '@/hooks/Mapper/types/routes.ts';
import { SolarSystemConnection } from '@/hooks/Mapper/types/connection.ts';
import { UserPermissions } from '@/hooks/Mapper/types';

export type MapUnionTypes = {
  wormholesData: Record<string, WormholeDataRaw>;
  wormholes: WormholeDataRaw[];
  effects: Record<string, EffectRaw>;
  characters: CharacterTypeRaw[];
  userCharacters: string[];
  presentCharacters: string[];
  hubs: string[];
  systems: SolarSystemRawType[];
  routes?: RoutesList;
  kills: Record<number, number>;
  connections: SolarSystemConnection[];
  userPermissions: Partial<UserPermissions>;
};
