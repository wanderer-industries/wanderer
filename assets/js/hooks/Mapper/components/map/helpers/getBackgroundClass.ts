import { isZarzakhSpace } from '@/hooks/Mapper/components/map/helpers/isZarzakhSpace.ts';
import {
  SECURITY_BACKGROUND_CLASSES,
  SYSTEM_CLASS_BACKGROUND_CLASSES,
  WORMHOLE_CLASS_BACKGROUND_CLASSES,
} from '@/hooks/Mapper/components/map/constants.ts';
import { isKnownSpace } from '@/hooks/Mapper/components/map/helpers/isKnownSpace.ts';
import { isWormholeSpace } from '@/hooks/Mapper/components/map/helpers/isWormholeSpace.ts';

export const getBackgroundClass = (systemClass: number, security: string) => {
  if (isZarzakhSpace(systemClass)) {
    return SYSTEM_CLASS_BACKGROUND_CLASSES[systemClass];
  } else if (isKnownSpace(systemClass)) {
    return SECURITY_BACKGROUND_CLASSES[security];
  } else if (isWormholeSpace(systemClass)) {
    return WORMHOLE_CLASS_BACKGROUND_CLASSES[systemClass];
  } else {
    return SYSTEM_CLASS_BACKGROUND_CLASSES[systemClass];
  }
};
