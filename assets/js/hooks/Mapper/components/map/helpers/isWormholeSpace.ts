import { SOLAR_SYSTEM_CLASS_IDS } from '@/hooks/Mapper/components/map/constants.ts';

export const isWormholeSpace = (wormholeClassID: number) => {
  switch (wormholeClassID) {
    case SOLAR_SYSTEM_CLASS_IDS.c1:
    case SOLAR_SYSTEM_CLASS_IDS.c2:
    case SOLAR_SYSTEM_CLASS_IDS.c3:
    case SOLAR_SYSTEM_CLASS_IDS.c4:
    case SOLAR_SYSTEM_CLASS_IDS.c5:
    case SOLAR_SYSTEM_CLASS_IDS.c6:
    case SOLAR_SYSTEM_CLASS_IDS.c13:
    case SOLAR_SYSTEM_CLASS_IDS.thera:
    case SOLAR_SYSTEM_CLASS_IDS.barbican:
    case SOLAR_SYSTEM_CLASS_IDS.vidette:
    case SOLAR_SYSTEM_CLASS_IDS.conflux:
    case SOLAR_SYSTEM_CLASS_IDS.redoubt:
    case SOLAR_SYSTEM_CLASS_IDS.sentinel:
      return true;
  }

  return false;
};
