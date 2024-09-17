import { SOLAR_SYSTEM_CLASS_IDS } from '@/hooks/Mapper/components/map/constants.ts';

export const isKnownSpace = (wormholeClassID: number) => {
  switch (wormholeClassID) {
    case SOLAR_SYSTEM_CLASS_IDS.hs:
    case SOLAR_SYSTEM_CLASS_IDS.ls:
    case SOLAR_SYSTEM_CLASS_IDS.ns:
    case SOLAR_SYSTEM_CLASS_IDS.zarzakh:
      return true;
  }

  return false;
};
